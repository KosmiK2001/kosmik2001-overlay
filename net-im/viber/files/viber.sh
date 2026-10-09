#!/bin/sh
# Обёртка запуска net-im/viber (устанавливается в /usr/bin/viber).
#
# Viber — проприетарный бинарь со своим Qt6 в /opt/viber/lib (RUNPATH
# $ORIGIN:$ORIGIN/lib), поэтому LD_LIBRARY_PATH ему не нужен. Задача обёртки —
# opt-in workarounds для проблем отрисовки из /etc/viber/viber.conf и PATH для
# qtpaths, который дёргает xdg-mime при отправке файлов.

VIBER_CONF="/etc/viber/viber.conf"
# shellcheck source=/dev/null
[ -r "$VIBER_CONF" ] && . "$VIBER_CONF"

# xdg-mime из Qt-набора спрашивает qtpaths; без него в логе
# "xdg-mime: line 885: qtpaths: command not found" (так же в AUR viber.sh.in).
for d in /usr/lib64/qt6/bin /usr/lib/qt6/bin /usr/lib/qt5/bin; do
	[ -d "$d" ] && PATH="$d:$PATH"
done
export PATH

# Принудительный X11-бэкенд: под Wayland/XWayland на nvidia Viber открывает
# прозрачное/чёрное окно (flathub com.viber.Viber#32).
if [ -n "$VIBER_FORCE_XCB" ]; then
	QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
	export QT_QPA_PLATFORM
fi

# Переключение RHI-бэкенда Qt Quick (opengl|vulkan).
if [ -n "$VIBER_QSG_BACKEND" ]; then
	QSG_RHI_BACKEND="$VIBER_QSG_BACKEND"
	export QSG_RHI_BACKEND
fi

# Полностью программный рендер Qt Quick (лечит чёрное окно, тормозит).
if [ -n "$VIBER_SOFTWARE_RENDER" ]; then
	QT_QUICK_BACKEND=software
	export QT_QUICK_BACKEND
fi

# Эмодзи: COLRv1 NotoColorEmoji Qt в Viber не рисуется (квадраты),
# flathub com.viber.Viber PR#121 отбивает COLRv1 через fontconfig.
if [ -n "$VIBER_EMOJI_FIX" ] && [ -r /usr/share/viber/viber-emoji-fontconf.conf ]; then
	FONTCONFIG_FILE="${FONTCONFIG_FILE:-/usr/share/viber/viber-emoji-fontconf.conf}"
	export FONTCONFIG_FILE
fi

# shellcheck disable=SC2086
exec /opt/viber/Viber $VIBER_EXTRA_ARGS "$@"
