# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1 meson systemd

DESCRIPTION="ASUS OLED display controller (daemon + kernel module + GTK3 GUI)"
HOMEPAGE="https://github.com/KosmiK2001/asus-oled"
SRC_URI="https://github.com/KosmiK2001/asus_oled/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/asus_oled-${PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="gtk3 module"

REQUIRED_USE="modules-compress? ( module )
	modules-sign? ( module )"

DEPEND="
	gtk3? ( x11-libs/gtk+:3 )
"
RDEPEND="${DEPEND}"

src_configure() {
	local emesonargs=(
		-Dgtk3=$(usex gtk3 true false)
	)
	meson_src_configure
}

src_compile() {
	# Build meson project (daemon + optional GUI)
	meson_src_compile

	# Build kernel module if requested
	if use module; then
		local modlist=( asus_oled=extra:kernel )
		local modargs=( SYSSRC="${KV_DIR}" SYSOUT="${KV_OUT_DIR}" )
		linux-mod-r1_src_compile
	fi
}

src_install() {
	meson_src_install

	if use module; then
		linux-mod-r1_src_install
	fi

	# Install systemd service
	systemd_dounit data/asus-oled-daemon.service

	# Install desktop file and icon if GTK3
	if use gtk3; then
		domenu data/asus-oled.desktop
		insinto /usr/share/icons/hicolor/64x64/apps
		doins data/icons/asus_oled_tray.png
	fi
}

pkg_postinst() {
	if use module; then
		# Run depmod for the installed module (linux-mod-r1_pkg_postinst)
		linux-mod-r1_pkg_postinst

		elog "Load the kernel module with:"
		elog "  modprobe asus_oled"
		elog ""
		elog "Add to /etc/modules-load.d/ for automatic loading:"
		elog "  echo asus_oled > /etc/modules-load.d/asus-oled.conf"
	fi

	elog "Start the daemon:"
	elog "  systemctl enable --now asus-oled-daemon"

	if use gtk3; then
		elog ""
		elog "Launch the GUI:"
		elog "  asus-oled-gui"
	fi
}
