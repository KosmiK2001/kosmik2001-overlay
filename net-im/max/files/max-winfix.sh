#!/bin/sh
# max-winfix.sh — гасит служебные окна процесса max-service: лишние плитки в
# панели задач и decoration («кусочек» рамки) вокруг окон-пустышек.
#
# ПРОБЛЕМА (диагностировано на Xenoserver, compiz+emerald, MATE):
#   Процесс max-service (звонковый SDK) создаёт ДВА верхнеуровневых окна без
#   полезного содержимого — 2x2 (WM_NAME "MAX") и 10x10. Оба помечены
#   _XEMBED_INFO (window, 0x1) — приложение пытается зарегистрировать их как
#   XEmbed-иконки трея; трея в сессии нет, и окна остаются обычными топлевелами.
#   Последствия, замеренные на живом клиенте:
#     * панель задач (wnck-applet) рисует лишнюю плитку «MAX»;
#     * Emerald вешает decoration: у окна 10x10 _NET_FRAME_EXTENTS = 6,6,30,6,
#       т.е. вокруг содержимого 10x10 видна рамка 22x46 с заголовком 30px —
#       тот самый «кусочек» на экране.
#
#   ЧТО ИМЕННО ЛЕЧИТ КАЖДУЮ ПРОБЛЕМУ (проверено на живом окне):
#   1) Признак окна. WM_CLASS НЕНАДЁЖЕН: у главного окна клиента он
#      ("max-service","MAX") — первый компонент общий со служебными, а окно-
#      плитка имеет второй компонент "MAX". Надёжный признак — имя процесса-
#      владельца: _NET_WM_PID -> /proc/PID/comm == "max-service".
#   2) Плитка в панели. Пока висит _XEMBED_INFO, панель считает окно
#      трей-иконкой и показывает его ВОПРЕКИ SKIP_TASKBAR. Нужно снять
#      _XEMBED_INFO + поставить _NET_WM_STATE_SKIP_TASKBAR/SKIP_PAGER.
#      Тип окна (DOCK/UTILITY/NORMAL) роли не играет — проверено.
#   3) «Кусочек» (decoration). Emerald декорирует окно, у которого нет
#      _MOTIF_WM_HINTS с отключёнными декорациями. Приложение само ставит их
#      2x2-окну (0x2,0x1,0x0,0x0,0x0) и ЗАБЫВАЕТ про 10x10 — оно и торчит.
#      Ставим _MOTIF_WM_HINTS = 0x2,0x1,0x0,0x0,0x0 (flags=DECORATIONS,
#      decorations=0) — _NET_FRAME_EXTENTS становится 0,0,0,0, рамка исчезает.
#
#   ВАЖНО: unmap/map окна (а служебные окна «мигают») СБРАСЫВАЕТ
#   _NET_WM_STATE — SKIP_TASKBAR теряется, и плитка возвращается. Поэтому
#   watcher следит за окнами весь срок жизни MAX: часто (0.5 с) первую минуту,
#   затем редко (5 с), и повторяет правку, если свойства слетели.
#
# Аргумент: PID основного процесса max (watcher выходит, когда тот умирает).
# Молча завершается, если нет X, xprop/xwininfo или /proc — обёртка не должна
# падать из-за этого.

MAXPID=$1
[ -n "$MAXPID" ] || exit 0
command -v xprop >/dev/null 2>&1 || exit 0
command -v xwininfo >/dev/null 2>&1 || exit 0
[ -n "$DISPLAY" ] || exit 0

i=0
while :; do
	kill -0 "$MAXPID" 2>/dev/null || break

	# часто в первую минуту (старт), затем редко — чтобы не жечь CPU,
	# но и не пропустить возврат свойств после unmap/map
	if [ "$i" -lt 120 ]; then
		NAP=0.5
	else
		NAP=5
	fi
	i=$((i + 1))

	for w in $(xwininfo -root -children 2>/dev/null | awk '/^ +0x/{print $1}'); do
		pid=$(xprop -id "$w" _NET_WM_PID 2>/dev/null | grep -oE '[0-9]+$')
		[ -n "$pid" ] || continue
		comm=$(cat "/proc/$pid/comm" 2>/dev/null)
		case "$comm" in
		max-service)
			# 1) убрать трей-претензию, иначе SKIP_TASKBAR не действует
			xem=$(xprop -id "$w" _XEMBED_INFO 2>/dev/null)
			case "$xem" in
			*"not found"*) ;;
			*) xprop -id "$w" -remove _XEMBED_INFO 2>/dev/null ;;
			esac

			# 2) снять с панели/пейджера
			st=$(xprop -id "$w" _NET_WM_STATE 2>/dev/null)
			case "$st" in
			*SKIP_TASKBAR*) ;;
			*)
				xprop -id "$w" -f _NET_WM_STATE 32a \
					-set _NET_WM_STATE \
					_NET_WM_STATE_SKIP_TASKBAR,_NET_WM_STATE_SKIP_PAGER 2>/dev/null
				;;
			esac

			# 3) убрать decoration Emerald («кусочек»)
			mot=$(xprop -id "$w" _MOTIF_WM_HINTS 2>/dev/null)
			case "$mot" in
			*"not found"*)
				xprop -id "$w" -f _MOTIF_WM_HINTS 32c \
					-set _MOTIF_WM_HINTS "0x2,0x1,0x0,0x0,0x0" 2>/dev/null
				;;
			esac
			;;
		esac
	done
	sleep "$NAP"
done
