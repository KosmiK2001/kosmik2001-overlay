#!/usr/bin/env bash
# =============================================================================
#  max_jail — транзиентный джейл для недоверенного приложения (мессенджер MAX)
#
#  ВСЁ применяется только к процессу / временным namespace и правилам:
#    - сеть:  собственный netns, veth в хост, ТОЛЬКО default route;
#             приватные сети (LAN/VPN/lo-прокси) = unreachable + REJECT;
#             DNS-allowlist: 77.88.8.8 8.8.8.8 9.9.9.9 1.1.1.1 (всё прочее - REJECT);
#             метка 0xa1 (policy-routing хоста) форвардный трафик не касается:
#             цепочка VPN в mangle матчит только -i brlan0/tap0/tun10.
#    - процессы: новый PID-ns + /proc с hidepid=2 (чужих не видно вообще).
#    - ФС:  mount-ns; в настоящем доме юзера (--home-dir) видны ТОЛЬКО каталоги
#           приложения (по умолчанию ~/.config/max, ~/.local/share/max,
#           ~/.cache/max), всё остальное в /home скрыто; /etc — белый список;
#           /root, /sys, /run, /var/log, /var/tmp, /var/lib/dbus — пусто.
#           /tmp НЕ маскируется (и так tmpfs; там X11-сокеты).
#    - env:  чистое -i окружение (никаких *_proxy), юзер = --juid (uid 1000),
#            все capability сброшены (capsh --drop=all).
#    - никаких изменений системы: сеть/маски умирают сами; создаются только
#            каталоги данных приложения в домашней папке пользователя.
#
#  Использование (root):
#    sudo ./max_jail.sh -- /bin/sh                  # шелл в джейле
#    sudo ./max_jail.sh --selftest                  # проверка изоляции изнутри
#    sudo ./max_jail.sh --x11 --dbus -- /usr/share/max/bin/max
#    sudo ./max_jail.sh --home-mode full -- /usr/share/max/bin/max  # ОТЛАДКА:
#        виден весь дом юзера (узнать, какие каталоги пишет приложение)
#  Опции:
#    -n ИМЯ      имя netns (default: maxjail)
#    -s A.B.C.D/L подсеть veth (default: 10.200.0.0/30)
#    -d DIR      бинд дополнительного каталога данных в ~/data
#    --juid N    uid приложения (default: 1000 = текущий пользователь)
#    --home-dir DIR  домашний каталог юзера (default: из /etc/passwd для JUID)
#    --home-mode appdirs|full   appdirs: видны только каталоги приложения
#              (default); full: виден весь дом (только для отладки/первого запуска)
#    --x11       передать DISPLAY/XAUTHORITY (сокет /tmp/.X11-unix общий)
#    --dbus      пробросить session dbus в ~/.dbus/session
#    --no-mask-etc  НЕ маскировать /etc (отладка)
#    --selftest  выполнить встроенные проверки изоляции
#    --          разделитель, далее — команда (default: /bin/sh)
#  Окружение-настройки: MAXJAIL_HOME_BINDS=".config/max .local/share/max .cache/max"
#  (какие подкаталоги дома видны), MAXJAIL_ETC_EXTRA="..." (доп. белый список /etc).
# =============================================================================
set -u

NS=maxjail
SUBNET="10.200.0.0/30"
GW="10.200.0.1"
JIP="10.200.0.2"
DATA=""
JUID=1000
HOME_MODE="appdirs"
HOME_DIR=""
X11=0
DBUS=0
SELFTEST=0
MASK_ETC=1
RUNNER_DIR=""
SOCAT_X_PID=""

DNS_ALLOW="77.88.8.8 8.8.8.8 9.9.9.9 1.1.1.1"
PRIV_NETS="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
# маскируются целиком (не /etc — там белый список ниже)
MASK_DIRS="/root /var/log /var/tmp /var/lib/dbus"
# белый список /etc: всё остальное (openvpn, xray, wireguard, portage, systemd, environment...) исчезает
ETC_KEEP="nsswitch.conf ld.so.cache ld.so.conf ld.so.conf.d localtime timezone os-release ssl pki ca-certificates.conf fonts xdg mime.types gtk-3.0 gtk-2.0 dbus-1 gai.conf protocols services rpc terminfo inputrc bashrc shells"
ETC_EXTRA="${MAXJAIL_ETC_EXTRA:-}"
# имя пользователя внутри джейла (псевдоним; host-овые имена не раскрываем)
JAILUSER="max"

usage() { sed -n '2,39p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) NS="$2"; shift 2 ;;
    -s) SUBNET="$2"; P="${SUBNET%/*}"; GW="${P%.*}.1"; JIP="${P%.*}.2"; shift 2 ;;
    -d) DATA="$2"; shift 2 ;;
    --juid) JUID="$2"; shift 2 ;;
    --home-dir) HOME_DIR="$2"; shift 2 ;;
    --home-mode) HOME_MODE="$2"; shift 2 ;;
    --x11) X11=1; shift ;;
    --dbus) DBUS=1; shift ;;
    --no-mask-etc) MASK_ETC=0; shift ;;
    --selftest) SELFTEST=1; shift ;;
    --) shift; break ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done

# --- дом и юзер: по умолчанию = текущий пользователь (uid из passwd) ---
if [[ -z "$HOME_DIR" ]]; then
  HOME_DIR=$(getent passwd "$JUID" | cut -d: -f6)
fi
HOME_DIR="${HOME_DIR%/}"
[[ -n "$HOME_DIR" && -d "$HOME_DIR" ]] || { echo "ERR: нет домашнего каталога $HOME_DIR для uid $JUID"; exit 1; }
REALUSER=$(basename "$HOME_DIR")
JUSER=$(getent passwd "$JUID" | cut -d: -f1)
[[ -n "$JUSER" ]] || { echo "ERR: uid $JUID не найден в /etc/passwd"; exit 1; }
# в маскированном режиме у нас свой passwd с псевдонимом max; в --no-mask-etc — хостовый
CAPSH_USER="$JUSER"; [[ $MASK_ETC -eq 1 ]] && CAPSH_USER="$JAILUSER"
# внутреннее имя приложения — ONEME (это его каталоги в доме: config/data/logs/cache)
# (keyring НЕ биндим из настоящего ~/.local/share/keyrings — отдельный каталог ниже)
HOME_BINDS="${MAXJAIL_HOME_BINDS:-.config/ONEME .local/share/ONEME .cache/ONEME}"
[[ "$HOME_MODE" == "full" || "$HOME_MODE" == "appdirs" ]] || { echo "ERR: --home-mode должен быть full|appdirs"; exit 1; }
RUNNER_DIR="/tmp/.maxjail-run-${BASHPID}"

if [[ $SELFTEST -eq 1 ]]; then
  CMD=(/bin/bash "$RUNNER_DIR/.selftest.sh")
else
  CMD=("$@")
  [[ ${#CMD[@]} -eq 0 ]] && CMD=(/bin/sh)
fi

[[ $EUID -eq 0 ]] || { echo "ERR: нужен root (sudo ./max_jail.sh ...)"; exit 1; }
for t in ip iptables unshare nsenter capsh; do
  command -v "$t" >/dev/null || { echo "ERR: нет $t"; exit 1; }
done

VETH="mv${BASHPID}"

cleanup() {
  ip netns del "$NS" 2>/dev/null
  ip link del "$VETH" 2>/dev/null
  rm -f /run/maxjail-resolv 2>/dev/null
  [[ -n "$RUNNER_DIR" ]] && rm -rf "$RUNNER_DIR" 2>/dev/null
  [[ -n "$SOCAT_X_PID" ]] && kill "$SOCAT_X_PID" 2>/dev/null
  # хостовые бинды стейджа (nvidia-девайсы) не умирают с netns — снять и удалить
  { for m in /tmp/.maxjail-stage/*; do umount "$m" 2>/dev/null; done; rm -rf /tmp/.maxjail-stage 2>/dev/null; } || true
  if [[ $X11 -eq 1 ]]; then
    # убрать доступ по uid (соединение локальное, si:localuser)
    DISPLAY=:0 XAUTHORITY="$HOME_DIR/.Xauthority" xhost -si:localuser:"$REALUSER" >/dev/null 2>&1 || true
  fi
}
trap 'cleanup' EXIT INT TERM
cleanup

set -e
[[ -n "$DATA" ]] && { mkdir -p "$DATA"; chown -R "$JUID":"$JUID" "$DATA" 2>/dev/null || true; }

# ---------- сеть (host-сторона) ----------
ip netns list | grep -qx "$NS" && { echo "ERR: netns $NS уже существует — джейл уже запущен?"; exit 1; }
# stale veth от прогонов, убитых kill -9 (trap/cleanup не сработали): мёртвый veth
# держит 10.200.0.1/30 -> возвратный SYN-ACK уходит в него и пропадает (X11-мост мёртв).
# Конкурентных прогонов нет (netns-check выше) — удаление безопасно.
for v in $(ip -o link | awk -F'[ :@]+' '/^[0-9]+: mv[0-9]+/{print $2}'); do
  ip link del "$v" 2>/dev/null || true
done
ip netns add "$NS"
ip link add "$VETH" type veth peer name jv1
ip link set jv1 netns "$NS"
ip addr add "$GW/30" dev "$VETH"
ip link set "$VETH" up

# ---------- сеть (внутри netns) ----------
NEX() { ip netns exec "$NS" "$@"; }
NEX ip addr add "$JIP/30" dev jv1
NEX ip link set lo up
NEX ip link set jv1 up
NEX ip route add default via "$GW"
for net in $PRIV_NETS; do
  NEX ip route add unreachable "$net" 2>/dev/null || true
done
NEX sysctl -qw net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 net.ipv4.ip_forward=0

# ---------- DNS-allowlist + приватные ----------
NEX iptables -P INPUT DROP
NEX iptables -P OUTPUT ACCEPT
NEX iptables -P FORWARD DROP
NEX iptables -A INPUT -i lo -j ACCEPT
NEX iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
for d in $DNS_ALLOW; do
  NEX iptables -A OUTPUT -d "$d" -p udp --dport 53 -j ACCEPT
  NEX iptables -A OUTPUT -d "$d" -p tcp --dport 53 -j ACCEPT
done
NEX iptables -A OUTPUT -p udp --dport 53 -j REJECT
NEX iptables -A OUTPUT -p tcp --dport 53 -j REJECT
for net in 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16; do
  NEX iptables -A OUTPUT -d "$net" -j REJECT
done

printf 'nameserver 77.88.8.8\nnameserver 8.8.8.8\noptions timeout:1 attempts:2\n' > /run/maxjail-resolv

# ---------- selftest (в RUNNER_DIR, читается из /tmp) ----------
if [[ $SELFTEST -eq 1 ]]; then
  mkdir -p "$RUNNER_DIR"
cat > "$RUNNER_DIR/.selftest.sh" <<'SELF_EOF'
#!/bin/bash
HOST_MID="__HOST_MID__"
REALUSER="__REALUSER__"
HOMEDIR="__HOME_DIR__"
failed=0
pass(){ echo "PASS  $1"; }
fail(){ echo "FAIL  $1"; failed=1; }
t_ok(){ if eval "$2" >/dev/null 2>&1; then pass "$1"; else fail "$1"; failed=1; fi; }

# 1. env без proxy
t_ok "env чист от proxy"            '! env | grep -qiE "(_proxy|no_proxy)"'
# 2. маршруты/правила
t_ok "VPN-интерфейсов в маршрутах нет" '! ip route | grep -qE "fastvpn|tun10|tap0|brlan0"'
t_ok "ровно один default route"      '[ $(ip route | grep -c "^default") -eq 1 ]'
t_ok "нет fwmark policy-rules"       '! ip rule | grep -q fwmark'
t_ok "нет таблиц обхода"              '! ip route show table all | grep -qE "table (youtube|instagram|telegram|viber)"'
# 3. сокеты
t_ok "слушающих TCP в джейле нет"     '! ss -tln 2>/dev/null | grep -q LISTEN'
# 4. DNS allowlist работает
t_ok "DNS 77.88.8.8 отвечает"        'dig +time=2 +tries=1 @77.88.8.8 ya.ru >/dev/null 2>&1'
t_ok "DNS 8.8.8.8 отвечает"          'dig +time=2 +tries=1 @8.8.8.8 ya.ru >/dev/null 2>&1'
# 5. прочие DNS недоступны
t_ok "локальный DNS 127.0.0.1:53 НЕ доступен"     '! dig +time=2 +tries=1 @127.0.0.1 ya.ru >/dev/null 2>&1'
t_ok "провайдерский DNS 185.112.140.5:53 НЕ доступен" '! timeout 3 bash -c "exec 3<>/dev/tcp/185.112.140.5/53" 2>/dev/null'
t_ok "LAN DNS 192.168.137.1:53 НЕ доступен"       '! timeout 3 bash -c "exec 3<>/dev/tcp/192.168.137.1/53" 2>/dev/null'
# 6. egress наружу есть
t_ok "egress TCP 1.1.1.1:443 доступен" 'timeout 5 bash -c "exec 3<>/dev/tcp/1.1.1.1/443" 2>/dev/null'
# 7. сервисы хоста недоступны
t_ok "прокси хоста 127.0.0.1:10808 НЕ доступен" '! timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/10808" 2>/dev/null'
t_ok "веб-сервер хоста 192.168.137.1:80 НЕ доступен" '! timeout 3 bash -c "exec 3<>/dev/tcp/192.168.137.1/80" 2>/dev/null'
# 8. чужие процессы
t_ok "чужих процессов не видно"       '! ps -eo comm 2>/dev/null | grep -qiE "viber|whatsapp|hermes|xray|openvpn"'
# 9. маскировка ФС (пути ОТСУТСТВУЮТ, а не пусты)
t_ok "/sys замаскирован (tmpfs)"      '[ "$(stat -f -c %T /sys)" = tmpfs ]'
t_ok "/proc смонтирован с hidepid"    'grep -q hidepid /proc/mounts'
t_ok "в /home только один дом (REALUSER)" '[ "$(ls /home)" = "$REALUSER" ]'
t_ok "дома других юзеров скрыты"      '[ ! -e /home/Storage ] && [ ! -e /home/vmail ]'
t_ok "/etc/openvpn отсутствует"       '[ ! -e /etc/openvpn ]'
t_ok "/etc/xray отсутствует"          '[ ! -e /etc/xray ]'
t_ok "/etc/wireguard отсутствует"     '[ ! -e /etc/wireguard ]'
t_ok "/etc/portage отсутствует"       '[ ! -e /etc/portage ]'
t_ok "/etc/environment отсутствует"   '[ ! -e /etc/environment ]'
t_ok "/etc/proxychains.conf отсутствует" '[ ! -e /etc/proxychains.conf ]'
t_ok "/etc/hosts пуст"               '[ ! -s /etc/hosts ]'
t_ok "machine-id не хостовый"         '[ "$(cat /etc/machine-id)" != "$HOST_MID" ]'
t_ok "/root пуст"                    '[ $(ls -A /root 2>/dev/null | wc -l) -eq 0 ]'
# 10. права
t_ok "все capability сброшены"        'grep -qE "^CapEff:[[:space:]]+0+$" /proc/self/status'
t_ok "uid непривилегированный"        '[ $(id -u) -ne 0 ]'
t_ok "HOME = реальный дом"            '[ "$HOME" = "$HOMEDIR" ]'
t_ok "каталог приложения ~/.local/share/ONEME виден"  '[ -d "$HOME/.local/share/ONEME" ]'
t_ok "~/.ssh отсутствует"             '[ ! -e "$HOME/.ssh" ]'
t_ok "~/.gnupg отсутствует"           '[ ! -e "$HOME/.gnupg" ]'
t_ok "~/.gitconfig отсутствует"       '[ ! -e "$HOME/.gitconfig" ]'
t_ok "запись в каталоги приложения работает" 'touch "$HOME/.local/share/ONEME/.wtest" && rm -f "$HOME/.local/share/ONEME/.wtest"'
t_ok "дом принадлежит юзеру (можно создавать каталоги)" 'mkdir -p "$HOME/.new-test" && rmdir "$HOME/.new-test"'
t_ok "в /etc/passwd только root и приложение" '[ $(wc -l < /etc/passwd) -le 2 ]'
echo "==== selftest: failed=$failed ===="
exit $failed
SELF_EOF
  sed -i -e "s/__HOST_MID__/$(cat /etc/machine-id 2>/dev/null)/" \
         -e "s/__REALUSER__/$REALUSER/" \
         -e "s|__HOME_DIR__|$HOME_DIR|" "$RUNNER_DIR/.selftest.sh"
  chmod 755 "$RUNNER_DIR/.selftest.sh"
fi

# ---------- раннер (без слоёв цитирования; под uid юзера стартует dbus+keyring) ----------
mkdir -p "$RUNNER_DIR"
CMD_Q=$(printf '%q ' "${CMD[@]}")
cat > "$RUNNER_DIR/.run.sh" <<RUNEOF
#!/bin/sh
# dbus + keyring ДОЛЖНЫ быть от юзера (root-демон отказывает клиенту uid!=0);
# раннер исполняется под \$(id -u)=1000 после capsh
if [ "\$MAXJAIL_DBUS" = "1" ]; then
  rm -f "\$HOME/.dbus-sock" /tmp/.maxjail-dbus-addr 2>/dev/null
  dbus-daemon --session --nofork --print-address=1 --address="unix:path=\$HOME/.dbus-sock" \
    > /tmp/.maxjail-dbus-addr 2>/dev/null &
  sleep 1
  export DBUS_SESSION_BUS_ADDRESS="\$(cat /tmp/.maxjail-dbus-addr 2>/dev/null)"
  if [ -n "\$DBUS_SESSION_BUS_ADDRESS" ]; then
    # старт демона и НЕинтерактивное создание/разблокировка keyring одним вызовом
    # (двухшаговый start+unlock плодит второй демон и виснет — гонка с приложением)
    eval "\$(printf '%s\n' \"\$MAXJAIL_KEYRING_PASS\" | gnome-keyring-daemon --unlock --start --components=secrets 2>/dev/null)" || true
    sleep 1
  fi
fi
exec $CMD_Q
RUNEOF
chmod 755 "$RUNNER_DIR/.run.sh"

# --- host-side значения для проброса (подставляются литералами) ---
# X11 и dbus-сокеты хоста — AF_UNIX и привязаны к netns ХОСТА: из джейла
# (свой netns) до них не достучаться. X11 решается TCP-релеем socat через veth
# + отдельный cookie для 10.200.0.1 (xauth add на X-сервер). dbus-EXTERNAL-auth
# требует unix-сокет с SO_PEERCRED — через TCP невозможен, поэтому dbus
# passthrough отключён (приложение работает и без него, только Warning).
SOCAT_X_PID=""
EXTRA_ENV=""
if [[ $X11 -eq 1 ]]; then
  if [[ -S /tmp/.X11-unix/X0 ]]; then
    # Прямой unix-сокет, БЕЗ TCP-релея: AF_UNIX пересекает netns через путь
    # (mount-ns общий), и главное — DRI2/DRI3 передают fd по SCM_RIGHTS, что
    # через socat-TCP невозможно (GLX-контекст не создать: BadValue).
    # Доступ: xhost +si:localuser:<пользователь> — сервер сверяет SO_PEERCRED
    # (джейл-процесс = uid 1000), xauth-куки не нужны.
    if command -v xhost >/dev/null 2>&1; then
      XAUTH="$HOME_DIR/.Xauthority"
      if DISPLAY=:0 XAUTHORITY="$XAUTH" xhost +si:localuser:"$REALUSER" >/dev/null 2>&1; then
        EXTRA_ENV="DISPLAY=:0"
        # GPU-проброс: nvidia-устройства (иначе клиент GLX не создаст контекст).
        # Стейдж на хосте -> JBODY смонтирует их в свой /dev (см. секцию /dev)
        mkdir -p /tmp/.maxjail-stage
        for dev in /dev/nvidia0 /dev/nvidiactl /dev/nvidia-modeset /dev/nvidia-uvm; do
          [ -e "$dev" ] || continue
          : > "/tmp/.maxjail-stage/$(basename "$dev")" 2>/dev/null || true
          mount --bind "$dev" "/tmp/.maxjail-stage/$(basename "$dev")" 2>/dev/null || true
        done
      else
        echo "WARN: xhost не смог добавить доступ (XAUTH=$XAUTH?) — X11 недоступен"
        X11=0
      fi
    else
      echo "WARN: x11-apps/xhost не установлен — X11 недоступен (emerge x11-apps/xhost)"
      X11=0
    fi
  else
    echo "WARN: сокета X0 нет, --x11 игнорируется"
    X11=0
  fi
fi
if [[ $DBUS -eq 1 ]]; then
  echo "NOTE: --dbus = локальные dbus-daemon + gnome-keyring (раннер под uid юзера; keyring пароль авто)"
  EXTRA_ENV="$EXTRA_ENV MAXJAIL_DBUS=1"
  # keyring-пароль: генерируем ОДИН раз и храним в root-only файле рядом с домом;
  # диалог gcr-prompter при этом больше не появляется (keyring создаётся и
  # разблокируется неинтерактивно)
  KEYRING_PASS_FILE="$HOME_DIR/.max-jail-keyring.pass"
  if [[ ! -s "$KEYRING_PASS_FILE" ]]; then
    umask 077
    head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$KEYRING_PASS_FILE"
    chmod 600 "$KEYRING_PASS_FILE" 2>/dev/null || true
  fi
  EXTRA_ENV="$EXTRA_ENV MAXJAIL_KEYRING_PASS=$(cat "$KEYRING_PASS_FILE")"
  # при первом запуске (нет keyring-файлов) — подсказать пароль для диалога
  if ! ls "$HOME_DIR/.local/share/keyrings.maxjail/"*.keyring >/dev/null 2>&1; then
    echo "======== ПЕРВЫЙ ЗАПУСК KEYRING ========"
    echo "В диалоге «Choose password for new keyring» введи пароль:"
    echo "    $(cat "$KEYRING_PASS_FILE")"
    echo "========================================"
  fi
fi

# machine-id джейла — СТАБИЛЬНЫЙ, переживает перезапуски. Случайный каждый раз =
# «новое устройство» для приложения -> QR-сессия и авторизация сгорают при рестарте
MACHINE_ID_FILE="$HOME_DIR/.max-jail-machine-id"
if [[ ! -s "$MACHINE_ID_FILE" ]]; then
  umask 077
  head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$MACHINE_ID_FILE"
  chmod 600 "$MACHINE_ID_FILE" 2>/dev/null || true
fi
MJID=$(cat "$MACHINE_ID_FILE")
EXTRA_ENV="$EXTRA_ENV MAXJAIL_MACHINE_ID=$MJID"

# ---------- тело джейла (выполнится в pid+mount+uts+ipc ns) ----------
read -r -d '' JBODY <<EOF || true
set -e

# --- не давать маскам распространиться на хост (root обычно shared) ---
mount --make-rprivate / 2>/dev/null || true

# --- свежие приватные ФС ---
umount /proc 2>/dev/null || true
mount -t proc proc /proc -o hidepid=2
mount -t tmpfs tmpfs /sys
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts -o mode=620
mknod -m 666 /dev/null c 1 3
mknod -m 666 /dev/zero c 1 5
mknod -m 666 /dev/full c 1 7
mknod -m 666 /dev/random c 1 8
mknod -m 666 /dev/urandom c 1 9
mknod -m 666 /dev/tty c 5 0
mknod -m 666 /dev/ptmx c 5 2
# nvidia-устройства из стейджа хоста (в tmpfs-/dev их нет по умолчанию);
# \$d — экранировано: разворачивается ВНУТРИ джейла, а не на хосте!
for d in nvidia0 nvidiactl nvidia-modeset nvidia-uvm; do
  [ -e "/tmp/.maxjail-stage/\$d" ] || continue
  : > "/dev/\$d" 2>/dev/null || true   # цель бинда: файл-заглушка (иначе EINVAL)
  mount --bind "/tmp/.maxjail-stage/\$d" "/dev/\$d" 2>/dev/null || true
done
ln -s /proc/self/fd /dev/fd
ln -s /proc/self/fd/0 /dev/stdin
ln -s /proc/self/fd/1 /dev/stdout
ln -s /proc/self/fd/2 /dev/stderr

# --- /home: настоящий дом юзера, видны ТОЛЬКО каталоги приложения ---
mkdir -p /tmp/.maxjail-stage
if [ "$HOME_MODE" = full ]; then
  # отладка: весь дом юзера (узнать, куда пишет приложение)
  mkdir -p /tmp/.maxjail-stage/home
  mount --bind $HOME_DIR /tmp/.maxjail-stage/home
else
  for d in $HOME_BINDS; do
    src="$HOME_DIR/\$d"
    [ -d "\$src" ] || mkdir -p "\$src"
    chown -R $JUID:$JUID "\$src" 2>/dev/null || true
    mkdir -p "/tmp/.maxjail-stage/\$d"
    mount --bind "\$src" "/tmp/.maxjail-stage/\$d" 2>/dev/null || true
  done
fi
# keyring джейла — ОТДЕЛЬНЫЙ хостовый каталог (НЕ настоящий ~/.local/share/keyrings!):
# стейдж на хосте, в джейле -> ~/.local/share/keyrings (mount --move)
# ВАЖНО: heredoc-строки разворачиваются как ТЕКСТ (set -u!) — без промежуточных переменных
mkdir -p /tmp/.maxjail-stage/keysrc
[ -d "$HOME_DIR/.local/share/keyrings.maxjail" ] || mkdir -p "$HOME_DIR/.local/share/keyrings.maxjail"
chown $JUID:$JUID "$HOME_DIR/.local/share/keyrings.maxjail" 2>/dev/null || true
mount --bind "$HOME_DIR/.local/share/keyrings.maxjail" /tmp/.maxjail-stage/keysrc 2>/dev/null || true
mount -t tmpfs tmpfs /home
mkdir -p /home/$REALUSER
# дом в джейле отдаём юзеру — приложение должно САМО создавать свои каталоги
# (tmpfs приватный, на хост не влияет)
chown $JUID:$JUID /home/$REALUSER
if [ "$HOME_MODE" = full ]; then
  mount --move /tmp/.maxjail-stage/home /home/$REALUSER
else
  for d in $HOME_BINDS; do
    mkdir -p "/home/$REALUSER/\$d"
    mount --move "/tmp/.maxjail-stage/\$d" "/home/$REALUSER/\$d" 2>/dev/null || true
  done
fi
# родительские каталоги дома — юзеру (root создал в tmpfs; иначе keyring/приложение
# не смогут создавать в них подкаталоги: Permission denied)
chown $JUID:$JUID /home/$REALUSER/.config /home/$REALUSER/.local \
  /home/$REALUSER/.local/share /home/$REALUSER/.cache 2>/dev/null || true
# keyring джейла: поднят в jail из /tmp/.maxjail-stage/keysrc (хостовый каталог,
# переживает перезапуски; вне настоящего keyrings юзера)
mkdir -p "/home/$REALUSER/.local/share/keyrings"
chown $JUID:$JUID "/home/$REALUSER/.local/share/keyrings" 2>/dev/null || true
mount --move /tmp/.maxjail-stage/keysrc "/home/$REALUSER/.local/share/keyrings" 2>/dev/null || true
if [ -n "$DATA" ]; then
  [ -d "$DATA" ] || mkdir -p "$DATA"
  mkdir -p "/home/$REALUSER/data"
  mount --bind "$DATA" "/home/$REALUSER/data"
  chown -R $JUID:$JUID "$DATA" 2>/dev/null || true
fi

# --- не-/etc маски ---
for d in $MASK_DIRS; do
  [ -e "\$d" ] || continue
  mount -t tmpfs masked "\$d" 2>/dev/null || true
done

# --- /etc: белый список (имена обходных конфигов исчезают совсем) ---
if [ "$MASK_ETC" = 1 ]; then
  mkdir -p /tmp/.maxjail-etc
  mount --bind /etc /tmp/.maxjail-etc
  mount -t tmpfs tmpfs /etc
  for e in $ETC_KEEP $ETC_EXTRA; do
    [ -e "/tmp/.maxjail-etc/\$e" ] || continue
    if [ -d "/tmp/.maxjail-etc/\$e" ]; then
      mkdir -p "/etc/\$e" 2>/dev/null || true
    else
      mkdir -p "/etc/\$(dirname "\$e")" 2>/dev/null || true
      : > "/etc/\$e" 2>/dev/null || true
    fi
    mount --bind "/tmp/.maxjail-etc/\$e" "/etc/\$e" 2>/dev/null || true
  done
  # localhost нужен приложению (внутренние RPC-компоненты); имена LAN-хостов НЕ раскрываем
  printf '127.0.0.1 localhost\n' > /etc/hosts
  # свой минимальный passwd/group: хостовые юзернеймы не раскрываем, дом — реальный
  printf 'root:x:0:0:root:/root:/bin/sh\n%s:x:%s:%s:%s:/home/%s:/bin/sh\n' "$JAILUSER" "$JUID" "$JUID" "$JAILUSER" "$REALUSER" > /etc/passwd
  # video (gid 27): доступ к nvidia-устройствам (660 root:video) для GL — capsh initgroups'ит
  printf 'root:x:0:\nvideo:x:27:%s\n%s:x:%s:\n' "$JAILUSER" "$JAILUSER" "$JUID" > /etc/group
  # machine-id: СТАБИЛЬНЫЙ из лаунчера (привязка сессии/устройства; host-овый не утекает)
  printf '%s' "$MJID" > /etc/machine-id
  if [ -d /var/lib/dbus ]; then
    printf '%s' "$MJID" > /var/lib/dbus/machine-id 2>/dev/null || true
  fi
fi

# --- DNS: allowlist-резолвер ---
if [ "$MASK_ETC" = 1 ]; then
  printf 'nameserver 77.88.8.8\nnameserver 8.8.8.8\n' > /etc/resolv.conf   # /etc — наш tmpfs
else
  printf 'nameserver 77.88.8.8\nnameserver 8.8.8.8\n' > /run/resolv.conf
  mount --bind /run/resolv.conf /etc/resolv.conf
fi

hostname maxjail

# XDG_RUNTIME_DIR — GLib/GTK-приложениям (gcr-prompter, portal) без него не показать окна
mkdir -p /tmp/.maxjail-xdg && chmod 700 /tmp/.maxjail-xdg && chown $JUID:$JUID /tmp/.maxjail-xdg 2>/dev/null || true

# cwd лаунчера (/home/.../Max/jail) в джейле не существует (дом замаскирован) —
# иначе getcwd()/QDir падают: переходим в стабильный каталог
cd /home/$REALUSER || cd / || true

exec env -i HOME=/home/$REALUSER USER=$JAILUSER LOGNAME=$JAILUSER \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  TERM=${TERM:-xterm} LANG=C.UTF-8 XDG_RUNTIME_DIR=/tmp/.maxjail-xdg QT_QUICK_BACKEND=software $EXTRA_ENV \
  capsh --user=$CAPSH_USER --drop=all -- -c "exec $RUNNER_DIR/.run.sh"
EOF

set +e
ip netns exec "$NS" unshare -p -m -u -i -f -- bash -s <<< "$JBODY"
RC=$?
cleanup
exit $RC