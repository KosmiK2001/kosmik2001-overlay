# Copyright 2026 kosmik2001
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# MAX собран на Qt6/QtWebEngine, почти все библиотеки бандлятся в
# /opt/max/lib64 (Qt6.11, FFmpeg 61, OpenSSL 3, libstdc++, своя libsecret);
# список ниже сверен по трём источникам: NEEDED главного бинаря (11 системных
# soname), поздние dlopen из lib64/*.so (GTK-тема/диалоги, NSS для WebEngine,
# pulse/alsa, EGL/GBM, ibus) и Depends официального .deb / Requires
# официального RPM-репозитория (download.max.ru/linux/rpm/el/9/x86_64).
#
# Установка в /opt/max (а не /usr/share): в бинарях нет жёстко зашитых
# абсолютных путей, qt.conf относительный (Prefix=..), RPATH относительный —
# перенос безопасен (проверено strings -a по всем ELF пакета). Официальные
# пакеты кладут то же дерево в /usr/share/max и делают /usr/bin/max через
# update-alternatives (postinst) — у нас единая обёртка, см. src_install.
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
	app-arch/bzip2
	app-arch/zstd
	app-misc/ca-certificates
	dev-libs/double-conversion
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libgcrypt:0
	dev-libs/md4c
	dev-libs/nspr
	dev-libs/nss
	dev-libs/wayland
	gnome-base/gsettings-desktop-schemas
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/harfbuzz
	media-libs/libglvnd
	media-libs/libpng
	media-libs/libpulse
	media-libs/libva
	media-libs/mesa
	sys-apps/dbus
	sys-apps/systemd
	sys-apps/xdg-desktop-portal
	sys-apps/util-linux
	sys-libs/zlib
	x11-libs/gtk+:3
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXaw
	x11-libs/libXres
	x11-libs/libXScrnSaver
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libvdpau
	x11-libs/xcb-util-cursor
	x11-libs/xcb-util-keysyms
	x11-libs/xcb-util-wm
	x11-themes/hicolor-icon-theme
	jail-net? (
		app-admin/sudo
		gnome-base/gnome-keyring
		net-firewall/iptables
		sys-apps/iproute2
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
# Запуск из каталога, который пересоздали под ногами (emerge --unmerge +
# emerge воссоздают /opt/max с ДРУГИМ инодом; отключённый носитель — то же
# самое). Проверка "[ -d $PWD ]" НЕ ловит этот случай: путь существует,
# bash'овский `pwd -P` тоже врёт (резолвит логический $PWD). Единственный
# надёжный признак — суффикс "(deleted)" у /proc/self/cwd. Без этого
# приложение абортит SIGABRT сразу после первой строки лога (воспроизведено).
case "$(readlink /proc/self/cwd 2>/dev/null)" in
	*'(deleted)') cd "$HOME" 2>/dev/null || cd / ;;
esac
# Программный рендер Qt Quick нужен ТОЛЬКО в джейле (там GL/EGL мёртв,
# он включён в max_jail.sh). На хосте он рисует чёрную полосу ~70px внизу
# окна (замер попиксельно: строки 604..673 яркости 0.0 против равномерных
# 77.7 при нативном GL) — здесь его НЕ ставим.
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

	# Провайдер Secret Service: приложение (бандловая libsecret) хранит ключ
	# своей SQLCipher-базы в коллекции "login". Без живого сервиса база
	# считается битой и удаляется на каждом запуске ("Database key is
	# incorrect, remove database" -> повторный QR-вход).
	if ! has_version gnome-base/gnome-keyring && ! has_version kde-frameworks/kwallet; then
		ewarn "Нет провайдера Secret Service (gnome-base/gnome-keyring): вход будет сбрасываться."
	fi
	# Портал-бэкенд: без него org.freedesktop.portal.Settings/FileChooser
	# отсутствуют -> тема не читается, диалоги выбора файлов не работают
	# (в логе соответствующие Warning). Для MATE/GTK подходит -gtk.
	if ! has_version sys-apps/xdg-desktop-portal-gtk \
		&& ! has_version sys-apps/xdg-desktop-portal-kde \
		&& ! has_version sys-apps/xdg-desktop-portal-wlr; then
		elog "Совет: поставь sys-apps/xdg-desktop-portal-gtk — тогда заработают тема (Settings),"
		elog "диалоги выбора файлов (FileChooser) и нотификации через портал."
	fi
	elog "Известные ограничения нативной сборки (не лечатся из пакета):"
	elog "  * трей — QtQuick.Labs.Platform требует QApplication, а клиент QGuiApplication;"
	elog "    в бандловом xcb-плагине нет ни StatusNotifier, ни XEmbed (см. max-internals.md §4);"
	elog "  * звонки — CallsSDK ждёт собственный локальный RPC-сервер, который не стартует;"
	elog "  * max-service (313 МБ в /opt/max/bin) в Linux-сборке никем не запускается."
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}