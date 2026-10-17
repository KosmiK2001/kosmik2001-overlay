# Copyright 2019-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CHROMIUM_LANGS="
	af am ar bg bn ca cs da de el en-GB en-US es es-419 et fa fi fil fr gu he hi
	hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr sv
	sw ta te th tr uk ur vi zh-CN zh-TW
"

# Версия Electron-рантайма. Собрано и проверено на 44.9.0 (Chrome 152).
# Бumping: проверить левый клик трея (нативный Activate), белое меню настроек,
# старт свёрнутым, прокси-поля; при поломке JS-совместимости — новый патч в files/.
EV="44.9.0"

inherit chromium-2 desktop unpacker xdg

DESCRIPTION="Unofficial WhatsApp Desktop client (Electron ${EV} runtime + oOthkOo app code)"
HOMEPAGE="https://github.com/oOthkOo/whatsapp-desktop"
SRC_URI="
	amd64? ( https://github.com/oOthkOo/whatsapp-desktop/releases/download/v${PV}/whatsapp-linux-x64.deb -> ${PN}-amd64-${PV}.deb )
	https://github.com/electron/electron/releases/download/v${EV}/electron-v${EV}-linux-x64.zip
"
S="${WORKDIR}"

# Electron bundles a bunch of things
LICENSE="
	MIT BSD BSD-2 BSD-4 AFL-2.1 Apache-2.0 Ms-PL GPL-2 GPL-3 LGPL-2.1 APSL-2
	unRAR OFL-1.1 CC-BY-SA-3.0 MPL-2.0 android public-domain all-rights-reserved
"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="bindist mirror"

# dev-libs/libayatana-appindicator НЕ нужен: Electron >=~30 не использует
# libappindicator — трей идёт через собственную SNI-реализацию Chromium
# (StatusIconLinuxDbus) с фолбэком на GtkStatusIcon. Левый клик (Activate)
# работает нативно, см. патч-комментарии ниже.
RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	dev-libs/expat
	dev-libs/nspr
	dev-libs/nss
	media-fonts/noto-emoji
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
"

# Патчи к коду приложения (из deb), все к opt/whatsapp-desktop/resources/app/:
# 0001: белое окно Настроек — missing @electron/remote initialize()
# 0002: tray left-click = toggle (USE=tray-toggle)
# 0003: прокси в main.js — новый API + схема http/socks5
# 0004/0005: UI прокси — отдельные поля IP и Port + выбор схемы
# 0006: new Buffer() -> Buffer.from() (Node 24 в Electron 44 удалил конструктор)
PATCHES=(
	"${FILESDIR}/0001-whatsapp-white-settings-fix.patch"
	"${FILESDIR}/0003-whatsapp-proxy-main.patch"
	"${FILESDIR}/0004-whatsapp-proxy-settings-js.patch"
	"${FILESDIR}/0005-whatsapp-proxy-settings-html.patch"
	"${FILESDIR}/0006-whatsapp-node24-buffer.patch"
)

IUSE="+tray-toggle"

QA_PREBUILT="opt/whatsapp-desktop/*"

pkg_pretend() {
	chromium_suid_sandbox_check_kernel_config
}

src_unpack() {
	unpacker "${PN}-amd64-${PV}.deb"
	unpack "electron-v${EV}-linux-x64.zip"
}

src_prepare() {
	default
	use tray-toggle && eapply "${FILESDIR}/0002-whatsapp-tray-toggle.patch"
	# cleanup languages (locales из electron-zip, верхний уровень WORKDIR)
	pushd "locales" || die
	chromium_remove_language_paks
	popd || die
}

src_configure() {
	chromium_suid_sandbox_check_kernel_config
	default
}

src_install() {
	for size in {64,128}; do
		doicon -s ${size} "usr/share/icons/hicolor/${size}x${size}/apps/whatsapp.png"
	done

	# Fix desktop file Version to a known spec value (upstream ships "0.5.4")
	sed -i -e 's/^Version=.*/Version=1.0/' usr/share/applications/whatsapp.desktop || die
	domenu usr/share/applications/whatsapp.desktop

	local DESTDIR="/opt/whatsapp-desktop"

	# --- Electron-рантайм из zip (бинарь там именуется `electron`; packager/deb
	# переименовывают его в имя приложения — делаем то же самое) ---
	exeinto "${DESTDIR}"
	newexe electron WhatsApp
	doexe chrome-sandbox chrome_crashpad_handler
	doexe *.so*

	insinto "${DESTDIR}"
	doins *.pak *.bin *.dat *.json version LICENSE LICENSES.chromium.html
	insopts -m0755
	doins -r locales

	# --- Код приложения из deb, с нашенскими патчами ---
	insinto "${DESTDIR}/resources"
	doins -r opt/whatsapp-desktop/resources/app

	# Chrome-sandbox requires the setuid bit to be specifically set.
	# see https://github.com/electron/electron/issues/17972
	fperms 4755 "${DESTDIR}"/chrome-sandbox

	dosym ../../"${DESTDIR}"/WhatsApp /opt/bin/WhatsApp
}
