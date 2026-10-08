# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Cairo-Dock: a light, fast, convenient dock — panel replacement for your desktop"
HOMEPAGE="https://github.com/Cairo-Dock/cairo-dock-core"
SRC_URI="https://github.com/Cairo-Dock/cairo-dock-core/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="+x11 +glx +egl wayland layer_shell systemd test"

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
S="${WORKDIR}/cairo-dock-core-${PV}"

src_install() {
	cmake_src_install
	# GNUInstallDirs/upstream ставят ман уже сжатым (.gz), а Portage затем
	# жмёт всё в docompress-каталогах второй раз. Отключаем автоматическое
	# сжатие для man-страницы: QA-нотис «compressed files were found in
	# docompress-ed directories» иначе не уходит.
	docompress -x /usr/share/man/man1/cairo-dock.1.gz
}

src_configure() {
	local mycmakeargs=(
		-Denable-x11-support=$(usex x11 ON OFF)
		-Denable-glx-support=$(usex glx ON OFF)
		-Denable-egl-support=$(usex egl ON OFF)
		-Denable-wayland-support=$(usex wayland ON OFF)
		# GNUInstallDirs в CMake 4 отдаёт CMAKE_INSTALL_MANDIR уже
		# абсолютным (/usr/share/man), а upstream клеит его после ${prefix}
		# (mandir = ${prefix}/${CMAKE_INSTALL_MANDIR}) → /usr/usr/share/man.
		# Возвращаем относительное значение, чтобы вышло /usr/share/man.
		-DCMAKE_INSTALL_MANDIR=share/man
		# Флаг читается только внутри if (WAYLAND_FOUND); передавать его при
		# выключенном wayland — значит получить QA-нотис «переменная не
		# использована», поэтому добавляем его условно.
		$(usex wayland "-Denable-wayland-protocols=ON" "")
		-Denable-gtk-layer-shell=$(usex layer_shell ON OFF)
	)
	cmake_src_configure
}
