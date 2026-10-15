#!/bin/sh
# max-winfix.sh — гасит служебные окна процесса max-service: лишние плитки в
# панели задач и decoration («кусочек» рамки) вокруг окна-пустышки.
#
# ПРОБЛЕМА (диагностировано на Xenoserver, compiz+emerald, MATE):
#   Процесс max-service (звонковый SDK) создаёт ДВА верхнеуровневых окна без
#   полезного содержимого — 2x2 (WM_NAME "MAX", именно оно даёт лишнюю плитку)
#   и 10x10. Оба помечены _XEMBED_INFO (window, 0x1) — приложение пытается
#   зарегистрировать их как XEmbed-иконки трея; при этом трея в сессии нет, и
#   окна остаются обычными топлевелами. Для WM/панели это выглядит так:
#     * панель задач (wnck-applet) рисует лишние плитки «MAX»;
#     * Emerald вешает decoration — у окна 10x10 замерено
#       _NET_FRAME_EXTENTS = 6,6,30,6, т.е. 22x46 пикселей рамки с заголовком
#       вокруг содержимого 10x10 («виден кусочек»).
#
#   ВАЖНО (проверено на живом окне):
#   1) WM_CLASS как признак НЕНАДЁЖЕН — у главного окна клиента он
#      ("max-service","MAX"), т.е. ПЕРВЫЙ компонент совпадает со служебными
#      окнами ("max-service","Max-service"). Фильтр по второму компоненту тоже
#      неверен: окно-плитка имеет класс ("max-service","MAX"). Надёжный
#      признак — имя процесса-владельца окна (_NET_WM_PID -> /proc/PID/comm):
#      главное окно принадлежит comm="max", служебные — comm="max-service".
#   2) Одного _NET_WM_STATE_SKIP_TASKBAR НЕ ХВАТАЕТ: пока на окне висит
#      _XEMBED_INFO, панель считает его трей-иконкой и показывает вопреки
#      SKIP_TASKBAR (замерено). Плитка уходит именно после СНЯТИЯ
#      _XEMBED_INFO; тип окна (DOCK/UTILITY/NORMAL) роли НЕ играет —
#      проверено: при снятом _XEMBED_INFO панель чистая и с NORMAL.
#      (Тип DOCK из r22 убран: он не нужен и даёт лишний риск — compiz
#      держит DOCK-слой поверх всех окон.)
#
# РЕШЕНИЕ: watcher (запускается обёрткой /usr/bin/max перед exec основного
#   бинаря) находит все окна, чей процесс-владелец — max-service, и:
#     * снимает _XEMBED_INFO (-remove), чтобы окно не считалось трей-иконкой;
#     * ставит _NET_WM_STATE_SKIP_TASKBAR + SKIP_PAGER.
#   Тип окна не трогаем. Главное окно (comm=max) не трогается.
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
# ~60 секунд (120 * 0.5с): служебные окна появляются при старте MAX и могут
# пересоздаваться (наблюдались разные PID и геометрии от запуска к запуску).
# После этого watcher не нужен и не должен висеть вечно.
while [ "$i" -lt 120 ]; do
	kill -0 "$MAXPID" 2>/dev/null || break
	i=$((i + 1))

	for w in $(xwininfo -root -children 2>/dev/null | awk '/^ +0x/{print $1}'); do
		pid=$(xprop -id "$w" _NET_WM_PID 2>/dev/null | grep -oE '[0-9]+$')
		[ -n "$pid" ] || continue
		comm=$(cat "/proc/$pid/comm" 2>/dev/null)
		case "$comm" in
		max-service)
			# уже обработано? (xembed снят И state стоит — тип окна не важен)
			xem=$(xprop -id "$w" _XEMBED_INFO 2>/dev/null)
			st=$(xprop -id "$w" _NET_WM_STATE 2>/dev/null)
			case "$st" in
			*SKIP_TASKBAR*)
				case "$xem" in ""|*"not found"*) continue ;; esac
				;;
			esac
			# снять _XEMBED_INFO: без этого окно считается трей-иконкой и
			# панель показывает его вопреки SKIP_TASKBAR (корень проблемы)
			xprop -id "$w" -remove _XEMBED_INFO 2>/dev/null
			xprop -id "$w" -f _NET_WM_STATE 32a \
				-set _NET_WM_STATE \
				_NET_WM_STATE_SKIP_TASKBAR,_NET_WM_STATE_SKIP_PAGER 2>/dev/null
			;;
		esac
	done
	sleep 0.5
done
