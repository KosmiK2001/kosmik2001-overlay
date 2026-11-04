#!/bin/sh
# viber-start-hidden — помощник net-im/viber: прячет окно Viber в трей сразу
# после старта (VIBER_START_HIDDEN=1 в /etc/viber/viber.conf).
# Использование: viber-start-hidden <PID viber>
#
# Зачем не в самом Viber: ключи StartMinimized/StartInBackground/AutoStart
# присутствуют в бинаре только как строки таблицы (соседи "Scenario args",
# SafeMode) — ни CLI-разбор, ни QML-настройки их не читают. Опция «запускать
# свёрнутым» в клиенте неактивна (гейтуется сервером), включить её из ebuild
# нельзя.
#
# Как работает: дожидается регистрации StatusNotifierItem Viber'а на D-Bus,
# затем ждёт, пока главное окно отобразится И приложение закончит загрузку,
# и один раз вызывает org.kde.StatusNotifierItem.Activate — ровно тот метод,
# который mate notification-area шлёт по левому клику. С пропатченным QML
# (USE=tray-toggle) это toggle: окно видимо -> прячется в трей.
#
# ПОЧЕМУ НЕЛЬЗЯ ПРЯТАТЬ СРАЗУ, КАК ПОЯВИЛОСЬ ОКНО (проверено на живом):
# в MainWindow.qml висит
#     onClosing: (close) => {
#         if (contentLoader.item instanceof StartupAnimation) { Qt.exit(0); return }
#         ...
#     }
# то есть пока идёт стартовая анимация, закрытие/скрытие окна = выход из
# приложения. Скрытие через 6 с после exec убивало Viber через ~30 с.
# Признак готовности — процесс перестал жечь CPU (стартовая загрузка ~100%,
# затем ~1%): ждём два подряд замера ниже порога. Проверено: скрытие по
# этому признаку (t≈12 с) — приложение живёт, окно в трее.
#
# Особенности D-Bus-разведки (измерено на живой сессии):
#  - у Viber 4 соединения шины, одно (WebEngine) не отвечает, и busctl
#    get-property ждёт на нём ~25 с (его --timeout на фазу подключения не
#    действует) — поэтому опрос идёт gdbus --timeout 1 (<=4 с на имя);
#  - имена берутся из busctl list по колонке PID (один вызов за проход),
#    найденное/мёртвые кэшируются, чтобы не долбить шину повторно;
#  - well-known имени org.kde.StatusNotifierItem-<pid>-1 у Viber нет,
#    иконка находится только опросом уникальных имён процесса.
#
# Запускается в фоне из /usr/bin/viber, сам Viber не трогает и не убивает.

VPID=${1:?usage: viber-start-hidden <pid>}
GDBUS=$(command -v gdbus)
BUSCTL=$(command -v busctl)
XWININFO=$(command -v xwininfo)
XDOTOOL=$(command -v xdotool)
for t in "$GDBUS" "$BUSCTL" "$XWININFO" "$XDOTOOL"; do
	[ -n "$t" ] || { echo "viber-start-hidden: нужны gdbus/busctl/xwininfo/xdotool" >&2; exit 0; }
done

TIMEOUT=${VIBER_START_HIDDEN_TIMEOUT:-180}
DEBUG_TAG=${VIBER_START_HIDDEN_DEBUG:-}
# При автостарте stderr уходит в никуда, поэтому с VIBER_START_HIDDEN_DEBUG=1
# пишем ещё и в файл — иначе причину «не спряталось» не увидеть.
if [ -n "$DEBUG_TAG" ]; then
	LOG=${XDG_CACHE_HOME:-$HOME/.cache}/viber-start-hidden.log
	: > "$LOG" 2>/dev/null || LOG=/dev/null
fi
dbg() {
	[ -n "$DEBUG_TAG" ] || return 0
	echo "vsh: $*" >&2
	[ -n "$LOG" ] && echo "$(date '+%T') vsh: $*" >> "$LOG"
	return 0
}

END_TS=$(( $(date +%s) + TIMEOUT ))
DEAD=''
ITEM=''

is_dead() { case " $DEAD " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# SNI-предмет у PID Viber: соединение, отвечающее Id == ViberPC
find_item() {
	local n id
	for n in $("$BUSCTL" --user list --no-legend 2>/dev/null \
			| awk -v p="$VPID" '$2==p {print $1}'); do
		[ "$n" = "$ITEM" ] && continue
		is_dead "$n" && continue
		id=$("$GDBUS" call --session --timeout 1 --dest "$n" \
			--object-path /StatusNotifierItem \
			--method org.freedesktop.DBus.Properties.Get \
			org.kde.StatusNotifierItem Id 2>/dev/null)
		case "$id" in
			*ViberPC*) echo "$n"; return 0 ;;
			*) DEAD="$DEAD $n" ;;
		esac
	done
	return 1
}

# видимо ли главное (большое) окно Viber
window_viewable() {
	local w state wid
	for w in $("$XDOTOOL" search --class Viber 2>/dev/null); do
		state=$("$XWININFO" -id "$w" 2>/dev/null) || continue
		wid=$(echo "$state" | awk '/^  Width:/{print $2}')
		case "${wid:-0}" in ''|*[!0-9]*) continue ;; esac
		[ "$wid" -gt 500 ] || continue
		echo "$state" | grep -q 'Map State: IsViewable' && return 0
	done
	return 1
}

# Сколько jiffies CPU процесс сжёг за 1 с (0 = простаивает)
cpu_delta() {
	local a b
	a=$(awk '{print $14+$15}' "/proc/$VPID/stat" 2>/dev/null) || return 1
	sleep 1
	b=$(awk '{print $14+$15}' "/proc/$VPID/stat" 2>/dev/null) || return 1
	echo $((b - a))
}

dbg "жду SNI-иконку Viber (PID $VPID, timeout ${TIMEOUT}s)"

while [ "$(date +%s)" -lt "$END_TS" ]; do
	kill -0 "$VPID" 2>/dev/null || { dbg "процесс завершился — выход"; exit 0; }
	ITEM=$(find_item)
	[ -n "$ITEM" ] && break
	sleep 2
done
[ -n "$ITEM" ] || { dbg "иконка не появилась — выход"; exit 0; }
dbg "иконка: $ITEM"

# Ждём реального отображения окна: Activate по ещё невидимому окну в toggle
# НЕ спрячет, а покажет (visible==false -> requestActivate).
while [ "$(date +%s)" -lt "$END_TS" ]; do
	window_viewable && break
	sleep 1
done
window_viewable || { dbg "окно не отобразилось — выход"; exit 0; }
dbg "окно видимо, жду готовности (CPU)"

# Ждём окончания стартовой загрузки: два подряд замера ниже порога.
# Порог 5 jiffies/с ≈ 5% одного ядра — старт Viber держит 40-100%.
READY=0
while [ "$(date +%s)" -lt "$END_TS" ]; do
	kill -0 "$VPID" 2>/dev/null || { dbg "процесс завершился — выход"; exit 0; }
	d=$(cpu_delta) || break
	if [ "${d:-99}" -le 5 ]; then
		READY=$((READY + 1))
		[ "$READY" -ge 2 ] && break
	else
		READY=0
	fi
done
if [ "$READY" -ge 2 ]; then
	dbg "загрузка завершена (CPU $d jiffies/s)"
else
	# не дождались простоя — скрываем, но с запасом по времени
	dbg "простоя не дождались, пауза ${VIBER_START_HIDDEN_DELAY:-10}s"
	sleep "${VIBER_START_HIDDEN_DELAY:-10}"
fi
window_viewable || { dbg "окно уже не видимо — выход"; exit 0; }

dbg "окно видимо -> Activate ($ITEM)"
"$GDBUS" call --session --timeout 3 --dest "$ITEM" \
	--object-path /StatusNotifierItem \
	--method org.kde.StatusNotifierItem.Activate 1 1 >/dev/null 2>&1
rc=$?
sleep 1
if window_viewable; then
	dbg "окно всё ещё видимо (rc=$rc) — повтор через 2 с"
	sleep 2
	"$GDBUS" call --session --timeout 3 --dest "$ITEM" \
		--object-path /StatusNotifierItem \
		--method org.kde.StatusNotifierItem.Activate 1 1 >/dev/null 2>&1
	rc=$?
	sleep 1
	window_viewable && dbg "окно всё ещё видимо после повтора" \
		|| dbg "скрыто со второй попытки"
else
	dbg "скрыто (rc=$rc)"
fi
exit $rc
