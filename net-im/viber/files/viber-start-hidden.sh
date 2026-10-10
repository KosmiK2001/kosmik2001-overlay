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
# затем (обязательно) пока главное окно реально отобразится IsViewable, и
# один раз вызывает org.kde.StatusNotifierItem.Activate — ровно тот метод,
# который mate notification-area шлёт по левому клику. С пропатченным QML
# (USE=tray-toggle) это toggle: окно видимо -> прячется в трей.
#
# Особенности D-Bus-разведки (измерено на живой сессии):
#  - у Viber 4 соединения шины, одно (WebEngine) не отвечает, и busctl
#    get-property ждёт на нём ~25с (его --timeout на фазу подключения не
#    действует) — поэтому опрос идёт gdbus --timeout 1 (<=4с на имя);
#  - имена берутся из busctl list по колонке PID (один вызов за проход),
#    найденное/мёртвые кэшируются, чтобы не долбить шину повторно.
#
# Запускается в фоне из /usr/bin/viber, сам Viber не трогает и не убивает.

VPID=${1:?usage: viber-start-hidden <pid>}
GDBUS=$(command -v gdbus)
BUSCTL=$(command -v busctl)
XWININFO=$(command -v xwininfo)
XDOTOOL=$(command -v xdotool)
[ -n "$GDBUS" ] && [ -n "$BUSCTL" ] && [ -n "$XWININFO" ] && [ -n "$XDOTOOL" ] || exit 0

TIMEOUT=${VIBER_START_HIDDEN_TIMEOUT:-60}
DEBUG_TAG=${VIBER_START_HIDDEN_DEBUG:-}
dbg() { [ -n "$DEBUG_TAG" ] && echo "vsh: $*" >&2; return 0; }

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

dbg "жду SNI-иконку Viber (PID $VPID, timeout ${TIMEOUT}s)"

while [ "$(date +%s)" -lt "$END_TS" ]; do
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
sleep "${VIBER_START_HIDDEN_DELAY:-1}"
window_viewable || { dbg "окно исчезло до вызова — выход"; exit 0; }
dbg "окно видимо -> Activate ($ITEM)"

"$GDBUS" call --session --timeout 3 --dest "$ITEM" \
	--object-path /StatusNotifierItem \
	--method org.kde.StatusNotifierItem.Activate 1 1 >/dev/null 2>&1
rc=$?
dbg "Activate rc=$rc"
exit $rc
