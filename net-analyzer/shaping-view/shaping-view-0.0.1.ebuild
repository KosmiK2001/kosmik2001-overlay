# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

DESCRIPTION="GTK3 viewer for the tc (traffic control) hierarchy: HTB classes, ingress mirred/ifb, live rates"
HOMEPAGE="https://github.com/KosmiK2001/shaping-view"
SRC_URI="https://github.com/KosmiK2001/shaping-view/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="+upx debug sanitize"

DEPEND="x11-libs/gtk+:3"
RDEPEND="${DEPEND}
	sys-apps/iproute2"

S="${WORKDIR}/shaping-view-${PV}"

src_configure() { :; }

src_compile() {
	local targets=(release)
	use debug && targets+=(debug)
	use sanitize && targets+=(sanitize)
	emake CC="$(tc-getCC)" "${targets[@]}"
}

src_install() {
	dobin shaping-view
	dodoc README.md
	docinto examples
	dodoc doc/class-names.example.conf
}
