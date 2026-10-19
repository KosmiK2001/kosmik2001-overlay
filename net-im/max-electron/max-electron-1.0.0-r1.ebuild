# Copyright 2026 kosmik2001
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# MAX Desktop — чистая Electron-обёртка над официальным веб-клиентом
# web.max.ru. Код приложения (main.js / preload.js / assets) — НАШ,
# аудируемый, лежит в https://github.com/KosmiK2001/max-electron (GPL-3).
#
# Рантайм Electron (= Chromium + Node) берётся ОФИЦИАЛЬНЫМ prebuilt-архивом с
# github.com/electron, SHA256 сверяется Manifest'ом. Сборку движка из
# исходников сознательно НЕ делаем: исходного tarball у Electron нет
# (Chromium+Node тянутся gclient-чекаутом по DEPS), синк требует сеть
# (portage network-sandbox его блокирует), нужны clang/lld/gn/depot_tools/
# rust-bindgen и ~120 ГБ, а время — часы-дни. Рецепт задокументирован в
# max-internals.md (по Arch electron44 PKGBUILD), если когда-нибудь
# понадобится.
EV="44.9.0"

inherit desktop xdg-utils

DESCRIPTION="MAX Messenger desktop client (Electron wrapper for web.max.ru)"
HOMEPAGE="https://github.com/KosmiK2001/max-electron"
SRC_URI="
	${HOMEPAGE}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/electron/electron/releases/download/v${EV}/electron-v${EV}-linux-x64.zip
"
S="${WORKDIR}"

# GPL-3 — наш код приложения. Рантайм Electron бандлит Chromium/Node/V8 и
# десятки мелких библиотек; список лицензий — как в net-im/whatsapp-desktop-bin.
LICENSE="
	GPL-3 MIT BSD BSD-2 BSD-4 Apache-2.0 ISC GPL-2 GPL-3 LGPL-2.1 LGPL-3
	OFL-1.1 MPL-2.0 CC-BY-SA-3.0 APSL-2 public-domain unRAR
	all-rights-reserved
"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

# strip ломает prebuilt-ELF рантайма; бинарники непереносимы (mirror)
RESTRICT="strip mirror"
QA_PREBUILT="opt/max-electron/*"

BDEPEND="app-arch/unzip"

# Системные библиотеки рантайма Chromium (сверено с net-im/whatsapp-desktop-bin,
# тот же Electron 44). dev-libs/libayatana-appindicator НЕ нужен: Electron>=30
# рисует трей собственной SNI-реализацией (StatusIconLinuxDbus) с фолбэком на
# GtkStatusIcon — левый клик работает нативно.
RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	dev-libs/expat
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-libs/glibc
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libnotify
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXcursor
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXtst
	x11-libs/libXScrnSaver
	x11-libs/pango
	x11-themes/hicolor-icon-theme
"

src_unpack() {
	# default_src_unpack умеет сам: .tar.gz -> распаковка, .zip -> unzip
	# (BDEPEND app-arch/unzip). Дерево приложения ляжет в
	# ${WORKDIR}/max-electron-${PV}/app, рантайм — в ${WORKDIR}.
	default
}

src_install() {
	local DEST="/opt/max-electron"

	# --- рантайм Electron: бинарь переименовывается в имя приложения ---
	exeinto "${DEST}"
	newexe "${WORKDIR}/electron" max-electron || die "нет electron в рантайме"
	doexe "${WORKDIR}/chrome-sandbox" "${WORKDIR}/chrome_crashpad_handler" || die
	doexe "${WORKDIR}"/*.so* || die

	insinto "${DEST}"
	doins "${WORKDIR}"/*.pak "${WORKDIR}"/*.bin "${WORKDIR}"/*.dat \
		"${WORKDIR}"/*.json "${WORKDIR}/version" "${WORKDIR}/LICENSE" \
		"${WORKDIR}/LICENSES.chromium.html" || die
	insopts -m0755
	doins -r "${WORKDIR}/locales" || die

	# --- наш код приложения ---
	insinto "${DEST}/resources"
	doins -r "${WORKDIR}/max-electron-${PV}/app" || die

	# chrome-sandbox требует setuid-бита
	fperms 4755 "${DEST}"/chrome-sandbox

	# --- обёртка запуска: только то, без чего нельзя запустить ---
	# 1) Вырезаем proxy-переменные. Рантайм бинарный и наследует окружение:
	#    Chromium читает http_proxy/HTTP_PROXY/ALL_PROXY сам, до того как
	#    наше приложение успеет выставить session.setProxy. На машине с
	#    обходом блокировок (xray 127.0.0.1:10809 в окружении) это пустило бы
	#    трафик российского неблокируемого мессенджера через VPN-инфраструктуру
	#    — ровно то, чего проект избегает. Приложение дублирует тот же запрет
	#    изнутри (applyProxy -> mode 'direct'), но окружение чище снять здесь.
	# 2) D-Bus: уважаем НАСЛЕДОВАННУЮ сессионную шину, если она жива. На этой
	#    машине их ДВЕ: реальная шина MATE-сессии — /tmp/dbus-* (на ней
	#    mate-notification-daemon, mate-panel, вся декстоп-жизнь), а
	#    /run/user/$(id -u)/bus — отдельная systemd-user-шина. Безусловный
	#    форс /run (паттерн обёртки Qt-клиента, лечивший мёртвую шину в ssh)
	#    уводил Electron на чужую шину: уведомления падали с
	#    «StartServiceByName … exited with status 1» (проверено notify-send:
	#    /tmp rc=0, /run — ошибка). Поэтому: живая унаследованная — оставляем;
	#    мёртвая/отсутствует (ssh, протухший терминал) — фолбэк на /run.
	# 3) Уход из мёртвого cwd (каталог пересоздан под ногами) — иначе
	#    Electron падает на старте.
	dodir /usr/bin
	{
		echo '#!/bin/sh'
		cat <<'BASE'
# MAX (Electron) — прямой выход в интернет: не наследуем proxy-окружение.
unset http_proxy https_proxy ftp_proxy all_proxy no_proxy \
      HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
# D-Bus: наследуем живую сессионную шину; фолбэк на systemd-user — только
# если унаследованная мертва (ssh/старый терминал). Проверка — ListNames
# с таймаутом: на мёртвой шине он не пройдёт.
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
	timeout 3 gdbus call --session --dest org.freedesktop.DBus \
		--object-path /org/freedesktop/DBus \
		--method org.freedesktop.DBus.ListNames >/dev/null 2>&1 ||
		unset DBUS_SESSION_BUS_ADDRESS
fi
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ -S "/run/user/$(id -u)/bus" ]; then
	export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi
[ -d "/run/user/$(id -u)" ] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"
# Запуск из каталога, пересозданного под ногами (мёртвый инод): надёжный
# признак — суффикс "(deleted)" у /proc/self/cwd; "[ -d $PWD]" не ловит.
case "$(readlink /proc/self/cwd 2>/dev/null)" in
	*'(deleted)') cd "$HOME" 2>/dev/null || cd / ;;
esac
exec /opt/max-electron/max-electron "$@"
BASE
	} > "${D}/usr/bin/max-electron" || die
	fperms 0755 /usr/bin/max-electron

	# .desktop: Exec на обёртку
	make_desktop_entry max-electron "MAX" max-electron \
		"Network;InstantMessaging;Chat" "StartupWMClass=max-electron"

	# иконки из ассетов приложения
	newicon -s 512 "${WORKDIR}/max-electron-${PV}/app/assets/icon.png" max-electron.png
	newicon -s 256 "${WORKDIR}/max-electron-${PV}/app/assets/icon-256.png" max-electron.png
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	elog "Движок Electron ${EV} — официальный prebuilt (SHA256 в Manifest)."
	elog "Аудируемый код приложения: ${ROOT}/opt/max-electron/resources/app"
	elog "(репа: https://github.com/KosmiK2001/max-electron, GPL-3)."
	elog "Запуск: max-electron (или пункт меню MAX). Трафик — напрямую:"
	elog "обёртка снимает proxy-переменные, приложение дублирует mode 'direct'."
	elog "Конфиг (трей/прокси/геометрия): ~/.config/max-electron/config.json."
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
