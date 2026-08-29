# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="Fusion Icon 2 - system tray for switching Compiz window managers"
HOMEPAGE="https://github.com/KosmiK2001/fusion-icon-2"
EGIT_REPO_URI="https://github.com/KosmiK2001/fusion-icon-2.git"
EGIT_BRANCH="main"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="**"
IUSE="+upx +file -gsettings"

# Взаимоисключающие: file и gsettings
REQUIRED_USE="?? ( file gsettings )"

DEPEND="dev-cpp/gtkmm:3.0
	gnome-base/librsvg
	media-gfx/imagemagick
	gsettings? ( dev-libs/glib:2 )
	upx? ( app-arch/upx )"
RDEPEND="${DEPEND}
	gnome-base/librsvg"

src_compile() {
	cd "${S}/src"
	local emake_args=(ICON_DIR="/usr/share/fusion-icon2" USE_UPX=$(usex upx 1 0))
	use gsettings && emake_args+=(USE_GSETTINGS=1)
	emake "${emake_args[@]}"
}

src_install() {
	local sizes="16 22 24 32 48 64 128 256"

	for size in ${sizes}; do
		insinto "/usr/share/icons/hicolor/${size}x${size}/apps"
		rsvg-convert -w ${size} -h ${size} "${S}/src/icons/marco.svg" -o "${T}/marco-${size}.png"
		doins "${T}/marco-${size}.png"
		rsvg-convert -w ${size} -h ${size} "${S}/src/icons/nvidia.svg" -o "${T}/nvidia-${size}.png"
		doins "${T}/nvidia-${size}.png"
	done

	insinto /usr/share/fusion-icon2
	doins "${S}/src/icons/marco.svg"
	doins "${S}/src/icons/nvidia.svg"
	doins "${S}/src/icons/fusion-icon.png"

	# иконка для меню (Icon=fusion-icon из fusion-icon2.desktop)
	insinto /usr/share/icons/hicolor/48x48/apps
	newins "${S}/src/icons/fusion-icon.png" fusion-icon.png

	rsvg-convert -w 48 -h 48 "${S}/src/icons/nvidia.svg" -o "${T}/nvidia.png"
	rsvg-convert -w 48 -h 48 "${S}/src/icons/marco.svg" -o "${T}/marco.png"
	insinto /usr/share/fusion-icon2
	doins "${T}/nvidia.png"
	doins "${T}/marco.png"

	if use gsettings; then
		insinto /usr/share/glib-2.0/schemas
		doins "${FILESDIR}/org.fusion-icon2.gschema.xml"
	fi

	insinto /usr/share/applications
	doins "${S}/src/fusion-icon2.desktop"

	dobin "${S}/src/fusion-icon2"
}

pkg_postinst() {
	gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
	if use gsettings; then
		glib-compile-schemas /usr/share/glib-2.0/schemas 2>/dev/null || true
	fi
}
