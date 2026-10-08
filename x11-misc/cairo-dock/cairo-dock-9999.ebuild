# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Cairo-Dock: a light, fast, convenient dock — panel replacement for your desktop"
HOMEPAGE="https://github.com/Cairo-Dock/cairo-dock-core"
EGIT_REPO_URI="https://github.com/Cairo-Dock/cairo-dock-core.git"
EGIT_BRANCH="master"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="**"

# Обязательные deps core (из CMakeLists.txt): glib-2.0>=2.40, gthread-2.0,
# cairo, librsvg-2.0, libxml-2.0, gl, glu, libcurl, libarchive, gtk+-3.0>=3.22.
# Плагины грузятся dlopen-ом и ставят RDEPEND на core + свои libs.
IUSE="+x11 +glx +egl wayland layer_shell systemd test"

# CMake тихо пропускает отсутствующий pkg. Флаги ниже только детерминируют
# enable-* варианты; реальный сбор того, что upstream считает "unstable"
# (Disks/Doncky/Scooby-Do/weblets), НЕ включаем в core.

RDEPEND="x11-libs/gtk+:3
	x11-libs/cairo
	gnome-base/librsvg:2
	dev-libs/glib:2
	dev-libs/libxml2:2
	media-libs/glu
	media-libs/libglvnd
	net-misc/curl
	app-arch/libarchive
	x11? (
		x11-libs/libX11
		x11-libs/libXtst
		x11-libs/libXcomposite
		x11-libs/libXrandr
		x11-libs/libXrender
	)
	wayland? (
		dev-libs/wayland
		dev-libs/libevdev
	)
	egl? ( media-libs/libglvnd )
	layer_shell? ( gui-libs/gtk-layer-shell )
	systemd? ( sys-apps/systemd )"

DEPEND="
	${RDEPEND}
	dev-util/intltool
	dev-util/wayland-scanner
	sys-devel/gettext
	virtual/pkgconfig
"

RESTRICT="test"

src_install() {
	cmake_src_install
	# См. релизный ebuild: upstream кладёт man уже сжатым, гасим docompress.
	docompress -x /usr/share/man/man1/cairo-dock.1.gz
}

src_configure() {
	local mycmakeargs=(
		-Denable-x11-support=$(usex x11 ON OFF)
		-Denable-glx-support=$(usex glx ON OFF)
		-Denable-egl-support=$(usex egl ON OFF)
		-Denable-wayland-support=$(usex wayland ON OFF)
		# См. комментарий в релизном ebuild: CMake 4 отдаёт MANDIR абсолютным.
		-DCMAKE_INSTALL_MANDIR=share/man
		$(usex wayland "-Denable-wayland-protocols=ON" "")
		-Denable-gtk-layer-shell=$(usex layer_shell ON OFF)
	)
	cmake_src_configure
}
