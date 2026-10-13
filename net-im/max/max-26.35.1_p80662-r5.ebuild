# Copyright 2026 kosmik2001
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Официальный дистрибутив — только .deb (репозиторий download.max.ru).
# MAX собран на Qt6/QtWebEngine, почти все библиотеки бандлятся в
# /opt/max/lib64 (Qt6.11, FFmpeg 61, OpenSSL 3, libstdc++); из системы
# нужен только X11/GL-слой + glib (список сверен по ldd с учётом
# RPATH=$ORIGIN/../lib64).
#
# Установка в /opt/max (а не /usr/share): в бинарях нет жёстко зашитых
# абсолютных путей, qt.conf относительный (Prefix=..), RPATH относительный —
# перенос безопасен (проверено strings -a по всем ELF пакета).
#
# USE="jail-net" (по умолчанию ВЫКЛ): /usr/bin/max становится обёрткой,
# которая при наличии маркера /etc/max/jail-net запускает приложение в
# изолированном окружении /usr/libexec/max-jail/max_jail.sh (собственный
# netns с единственным default-route, DNS-allowlist 77.88.8.8/8.8.8.8/
# 9.9.9.9/1.1.1.1, маски ФС, hidepid=2, env -i без *_proxy). Маркер и
# лаунчер ставятся ТОЛЬКО с этим флагом.
MY_PN="MAX"
MY_PV="26.35.1.80662"

DESCRIPTION="MAX Messenger Desktop client (proprietary, Qt6/QtWebEngine)"
HOMEPAGE="https://max.ru/"
SRC_URI="https://download.max.ru/linux/deb/pool/main/m/max/${MY_PN}-${MY_PV}.deb"

LICENSE="all-rights-reserved" # проприетарный клиент, нет явной лицензии
SLOT="0"
KEYWORDS="~amd64"
IUSE="jail-net"

# НЕ шиповать и НЕ пересобирать бандловые бинарники: strip ломает
# QtWebEngine/их .so; все ELF — prebuilt.
RESTRICT="strip mirror test"
QA_PREBUILT="*"

BDEPEND="app-arch/dpkg"

RDEPEND="
	app-cdr/cdrtools
	app-crypt/libsecret
	app-arch/bzip2
	app-arch/zstd
	app-misc/ca-certificates
	dev-libs/double-conversion
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libgcrypt:0
	dev-libs/md4c
	dev-libs/wayland
	gnome-base/gsettings-desktop-schemas
	media-libs/fontconfig
	media-libs/freetype
	media-libs/harfbuzz
	media-libs/libglvnd
	media-libs/libpng
	media-libs/libva
	sys-apps/systemd
	sys-apps/util-linux
	sys-libs/zlib
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXScrnSaver
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libvdpau
	x11-libs/xcb-util-cursor
	x11-libs/xcb-util-keysyms
	x11-libs/xcb-util-wm
	x11-themes/hicolor-icon-theme
	jail-net? (
		app-crypt/gnome-keyring
		net-firewall/iptables
		net-misc/iproute2
		sys-apps/dbus
		sys-apps/sudo
		sys-libs/libcap
		x11-apps/xhost
	)
"

# Qt6-плагины ищут локали/ресурсы относительно бинарника (qt.conf: Prefix=..)
S="${WORKDIR}"

inherit xdg-utils

src_unpack() {
	dpkg-deb -x "${DISTDIR}/${A}" "${S}" || die "dpkg-deb -x failed"
}

src_install() {
	# всё дерево приложения: deb несёт usr/share/max -> ставим в /opt/max
	insinto /opt
	doins -r "${S}/usr/share/max" || die

	# исполняемые файлы (doins ставит 0644 — восстанавливаем +x)
	fperms 0755 \
		/opt/max/bin/max \
		/opt/max/bin/crashpad_handler \
		/opt/max/bin/max-service/bin/max-service

	# единая точка запуска — обёртка /usr/bin/max (обычный режим или джейл)
	dodir /usr/bin
	cat > "${D}/usr/bin/max" <<'EOF'
#!/bin/sh
# MAX — единая точка запуска. При USE="jail-net" (маркер /etc/max/jail-net)
# запуск идёт через изолированное окружение max_jail.sh.
if [ -f /etc/max/jail-net ]; then
	exec sudo -n /usr/libexec/max-jail/max_jail.sh --x11 --dbus -- /opt/max/bin/max "$@"
fi
# Живая сессионная шина + runtime-dir: всегда берём systemd-user-bus, если она
# существует — в ssh/старых сессиях DBUS_SESSION_BUS_ADDRESS может указывать на
# мёртвую шину, а приложению нужен живой Secret Service (launch.cpp:102 — иначе
# Fatal "libsecret unavailable"; проверено: без XDG_RUNTIME_DIR тоже падает).
if [ -S "/run/user/$(id -u)/bus" ]; then
	export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi
if [ -d "/run/user/$(id -u)" ]; then
	export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
# Программный рендер Qt Quick: без него приложение молча умирает на
# инициализации GL/EGL (проверено и на хосте, и в джейле), с ним — живёт
# и показывает окно.
export QT_QUICK_BACKEND=software
exec /opt/max/bin/max "$@"
EOF
	fperms 0755 /usr/bin/max

	# .desktop: Exec -> наша обёртка (в deb жёстко прописан /usr/share/max/bin/max);
	# DBusActivatable=true без dbus-сервиса в пакете — выпиливаем (QA-валидация)
	insinto /usr/share/applications
	sed -e 's#^Exec=.*#Exec=/usr/bin/max %U#' -e '/^DBusActivatable=/d' \
		"${S}/usr/share/applications/max.desktop" \
		> "${D}/usr/share/applications/max.desktop" || die
	insinto /usr/share/pixmaps
	doins "${S}/usr/share/pixmaps/max.png"

	local size
	for size in 16 24 32 48 64 128 256 512; do
		insinto "/usr/share/icons/hicolor/${size}x${size}/apps"
		doins "${S}/usr/share/icons/hicolor/${size}x${size}/apps/max.png"
	done

	if use jail-net; then
		# лаунчер джейла + маркер включения
		exeinto /usr/libexec/max-jail
		doexe "${FILESDIR}/max_jail.sh"
		insinto /usr/libexec/max-jail
		doins "${FILESDIR}/README.jail.md"
		keepdir /etc/max
		touch "${D}/etc/max/jail-net" || die
	fi
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	if use jail-net; then
		elog "Изолированный запуск включён (/usr/bin/max -> max_jail.sh)."
		elog "Запуск требует passwordless sudo; добавь в sudoers:"
		elog "  %wheel ALL=(root) NOPASSWD: /usr/libexec/max-jail/max_jail.sh"
		elog "Данные приложения: ~/.config/ONEME, ~/.local/share/ONEME, ~/.cache/ONEME."
		elog "Вернуться к обычному запуску: emerge -1 net-im/max (без jail-net)."
	else
		elog "Обычный запуск: /usr/bin/max (или пункт меню MAX)."
		elog "Изоляция при желании: USE='jail-net' emerge -1 net-im/max."
	fi
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}