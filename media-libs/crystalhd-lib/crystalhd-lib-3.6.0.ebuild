# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Broadcom Crystal HD Decoder userspace library (BCM70012/BCM70015)"
HOMEPAGE="https://github.com/KosmiK2001/crystalhd-lib"
SRC_URI="https://github.com/KosmiK2001/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~amd64"

IUSE="crystalhd-kmod"
RDEPEND="crystalhd-kmod? ( media-video/crystalhd-kmod )"

src_compile() {
	emake -C lib
}

src_install() {
	dolib.so lib/libcrystalhd.so.3.6
	dosym libcrystalhd.so.3.6 /usr/lib/libcrystalhd.so.3
	dosym libcrystalhd.so.3.6 /usr/lib/libcrystalhd.so
	insinto /usr/include
	doins include/*.h
	insinto /usr/include/link
	doins include/link/*.h
	insinto /usr/include/flea
	doins include/flea/*.h
}
