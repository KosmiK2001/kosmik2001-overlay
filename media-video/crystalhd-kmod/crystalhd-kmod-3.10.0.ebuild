# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1

DESCRIPTION="Broadcom Crystal HD Decoder kernel module (BCM70012/BCM70015)"
HOMEPAGE="https://github.com/KosmiK2001/crystalhd-kmod"
SRC_URI="https://github.com/KosmiK2001/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

src_compile() {
	local modlist=( crystalhd=kernel:. )
	linux-mod-r1_src_compile
}

src_install() {
	linux-mod-r1_src_install
	insinto /lib/firmware
	doins firmware/fwbin/70015/bcm70015fw.bin
	doins firmware/fwbin/70012/bcm70012fw.bin
}
