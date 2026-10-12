# Copyright 2019-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CHROMIUM_LANGS="
	am ar bg bn ca cs da de el en-GB en-US es es-419 et fa fi fil fr gu he hi
	hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr sv
	sw ta te th tr uk vi zh-CN zh-TW
"

inherit chromium-2 desktop unpacker xdg

DESCRIPTION="Unofficial electron-based wrapper around WhatsApp Web"
HOMEPAGE="https://github.com/oOthkOo/whatsapp-desktop"
SRC_URI="
	amd64? ( https://github.com/oOthkOo/whatsapp-desktop/releases/download/v${PV}/whatsapp-linux-x64.deb -> ${PN}-amd64-${PV}.deb )
	x86? ( https://github.com/oOthkOo/whatsapp-desktop/releases/download/v${PV}/whatsapp-linux-ia32.deb -> ${PN}-x86-${PV}.deb )
"
S="${WORKDIR}"

# Electron bundles a bunch of things
LICENSE="
	MIT BSD BSD-2 BSD-4 AFL-2.1 Apache-2.0 Ms-PL GPL-2 GPL-3 LGPL-2.1 APSL-2
	unRAR OFL-1.1 CC-BY-SA-3.0 MPL-2.0 android public-domain all-rights-reserved
"
SLOT="0"
KEYWORDS="-* ~amd64 ~x86"

RESTRICT="bindist mirror"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	dev-libs/expat
	dev-libs/libayatana-appindicator
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

QA_PREBUILT="opt/whatsapp-desktop/*"

pkg_pretend() {
	chromium_suid_sandbox_check_kernel_config
}

# Patches in files/ — see metadata.xml <use> for what each does.
# 0001: white settings menu fix (missing @electron/remote initialize())
# 0002: tray left-click toggles show/hide (like Viber) — USE=tray-toggle
# 0003: proxy scheme support (http/socks5) in main process
# 0004: proxy settings UI — separate IP and Port fields
# 0005: proxy settings HTML — scheme/IP/Port inputs
PATCHES=(
	"${FILESDIR}/0001-whatsapp-white-settings-fix.patch"
	"${FILESDIR}/0003-whatsapp-proxy-main.patch"
	"${FILESDIR}/0004-whatsapp-proxy-settings-js.patch"
	"${FILESDIR}/0005-whatsapp-proxy-settings-html.patch"
)

IUSE="+tray-toggle"

src_prepare() {
	default
	use tray-toggle && eapply "${FILESDIR}/0002-whatsapp-tray-toggle.patch"
	# cleanup languages
	pushd "opt/whatsapp-desktop/locales" || die
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
	# libappindicator is REQUIRED: MATE notification area here is SNI-only
	# (_NET_SYSTEM_TRAY_S0 absent), so without it Electron falls back to
	# GtkStatusIcon (XEmbed) and the icon would not appear at all.
	# NOTE: on this SNI path Electron 17 does NOT expose the Activate method,
	# so tray left-clicks never reach the app (upstream-commented limitation);
	# the tray context menu (Show/Hide/Quit) is the working interaction.
	dosym "../../usr/lib64/libayatana-appindicator3.so" "${DESTDIR}/libappindicator3.so"

	pushd "opt/whatsapp-desktop" || die

	exeinto "${DESTDIR}"
	doexe chrome-sandbox WhatsApp *.so*

	exeinto "${DESTDIR}/swiftshader"
	doexe swiftshader/*.so*

	insinto "${DESTDIR}"
	doins *.pak *.bin *.json *.dat
	insopts -m0755
	doins -r locales resources

	# Chrome-sandbox requires the setuid bit to be specifically set.
	# see https://github.com/electron/electron/issues/17972
	fperms 4755 "${DESTDIR}"/chrome-sandbox

	dosym ../../"${DESTDIR}"/WhatsApp /opt/bin/WhatsApp
	popd || die
}
