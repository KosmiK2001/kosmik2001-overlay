#!/bin/sh
# max-winfix.sh — гасит служебное окно-пустышку MAX в панели задач и декорациях.
#
# ПРОБЛЕМА (диагностировано на Xenoserver, compiz+emerald, MATE):
#   Процесс max-service (звонковый SDK) создаёт верхнеуровневое окно 10x10
#   БЕЗ _NET_WM_WINDOW_TYPE. Для WM оно выглядит обычным клиентом, поэтому:
#     * панель задач (wnck-applet) рисует вторую плитку «MAX»;
#     * Emerald вешает decoration — _NET_FRAME_EXTENTS = 6,6,30,6, т.е. вокруг
#       окна 10x10 появляется рамка с заголовком 30px («виден кусочек»).
#   Проверено: у главного окна клиента WM_CLASS = ("max-service","MAX"), у
#   служебного — ("max-service","Max-service"); совпадает ПЕРВЫЙ компонент,
#   поэтому фильтровать нужно строго по ВТОРОМУ.
#
# РЕШЕНИЕ: watcher (запускается обёрткой /usr/bin/max перед exec основного
#   бинаря) находит окно с вторым компонентом WM_CLASS ровно "Max-service" и
#   выставляет ему _NET_WM_STATE_SKIP_TASKBAR + SKIP_PAGER и тип
#   _NET_WM_WINDOW_TYPE_UTILITY — панель плитку убирает, Compiz перестаёт
#   декорировать, «кусочек» исчезает.
#
# Аргумент: PID основного процесса max (watcher выходит, когда тот умирает).
# Молча завершается, если нет X, xprop или xwininfo — обёртка не должна падать.

MAXPID=$1
[ -n "$MAXPID" ] || exit 0
command -v xprop >/dev/null 2>&1 || exit 0
command -v xwininfo >/dev/null 2>&1 || exit 0
[ -n "$DISPLAY" ] || exit 0

i=0
# ~30 секунд (60 * 0.5с): окно-пустышка появляется при старте MAX. Дальше
# watcher не нужен и не должен висеть вечно.
while [ "$i" -lt 60 ]; do
	kill -0 "$MAXPID" 2>/dev/null || break
	i=$((i + 1))

	for w in $(xwininfo -root -children 2>/dev/null | awk '/^ +0x/{print $1}'); do
		cls=$(xprop -id "$w" WM_CLASS 2>/dev/null)
		case "$cls" in
		*'"Max-service"'*)	# точный признак служебного окна
			st=$(xprop -id "$w" _NET_WM_STATE 2>/dev/null)
			case "$st" in
			*SKIP_TASKBAR*) ;;	# уже обработано в этом запуске
			*)
				xprop -id "$w" -f _NET_WM_STATE 32a \
					-set _NET_WM_STATE \
					_NET_WM_STATE_SKIP_TASKBAR,_NET_WM_STATE_SKIP_PAGER 2>/dev/null
				xprop -id "$w" -f _NET_WM_WINDOW_TYPE 32a \
					-set _NET_WM_WINDOW_TYPE \
					_NET_WM_WINDOW_TYPE_UTILITY 2>/dev/null
				;;
			esac
			;;
		esac
	done
	sleep 0.5
done
