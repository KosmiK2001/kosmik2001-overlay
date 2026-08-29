# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Revived fork of app-eselect/eselect-opengl (removed from the Gentoo tree
# on 2020-09-12). Providers live in /usr/lib*/opengl/<impl>/lib and are
# populated by driver ebuilds:
#   xorg-x11  - libglvnd-based mesa (libGL.so.1 -> glvnd libGL)
#   nvidia    - legacy non-glvnd nvidia (e.g. 340.108)
#   fglrx     - legacy non-glvnd ATI/AMD (Catalyst)
# Switching is done via /etc/env.d/000opengl (LDPATH + OPENGL_PROFILE) and
# /etc/X11/xorg.conf.d/20opengl.conf (ModulePath), exactly like the original.

EAPI=8

DESCRIPTION="Utility to switch between OpenGL implementations (mesa/glvnd, legacy nvidia, fglrx)"
HOMEPAGE="https://github.com/KosmiK2001/eselect-opengl"
SRC_URI="https://github.com/KosmiK2001/eselect-opengl/releases/download/${PV}/${P}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"

RDEPEND=">=app-admin/eselect-1.2.4
	sys-apps/kmod
	sys-apps/pciutils"


S="${WORKDIR}/${P}"

src_install() {
	insinto /usr/share/eselect/modules
	newins opengl.eselect opengl.eselect

	exeinto /usr/libexec
	newexe opengl-detect opengl-detect

	# boot-time provider detection, runs before any display manager
	insinto /etc/systemd/system
	doins opengl-detect.service
}

pkg_preinst() {
	# remember the currently selected implementation across upgrades;
	# the broken self-made module from earlier sessions may print garbage,
	# so only accept a value that matches an existing provider dir
	OLD_IMPL=$(eselect opengl show 2>/dev/null)
	[[ -d "${EROOT}"/usr/lib64/opengl/${OLD_IMPL} ]] || OLD_IMPL=""
}

pkg_postinst() {
	# make sure the glvnd mesa provider (xorg-x11) exists: a single libGL.so.1
	# symlink is enough, libGLX/libGLdispatch resolve from /usr/lib64
	local d="${EROOT}/usr/lib64/opengl/xorg-x11/lib"
	if [[ -e ${EROOT}/usr/lib64/libGL.so.1 && ! -e ${d}/libGL.so.1 ]]; then
		mkdir -p "${d}"
		ln -sfn /usr/lib64/libGL.so.1 "${d}/libGL.so.1"
		ln -sfn /usr/lib64/libGL.so   "${d}/libGL.so"
		einfo "Created glvnd mesa OpenGL provider (xorg-x11)."
	fi

	if [[ -n ${OLD_IMPL} ]]; then
		eselect opengl set "${OLD_IMPL}"
	elif [[ ! -f "${EROOT}/etc/env.d/000opengl" ]]; then
		elog "No OpenGL profile selected yet."
		elog "Run 'eselect opengl list' and 'eselect opengl set <impl>'."
	elog "Enable boot-time provider detection with:"
	elog "  systemctl enable opengl-detect.service"
	fi
}
