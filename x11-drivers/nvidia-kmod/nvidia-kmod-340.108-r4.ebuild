# Copyright 2021-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit linux-mod-r1 readme.gentoo-r1 unpacker

MODULES_KERNEL_MAX=6.15
NV_URI="https://download.nvidia.com/XFree86/"

DESCRIPTION="NVIDIA Accelerated Graphic Driver - kernel module (AUR patches)"
HOMEPAGE="https://www.nvidia.com/download/index.aspx"
SRC_URI="
	amd64? ( ${NV_URI}Linux-x86_64/${PV}/NVIDIA-Linux-x86_64-${PV}.run )
	x86? ( ${NV_URI}Linux-x86/${PV}/NVIDIA-Linux-x86-${PV}.run )
"

LICENSE="NVIDIA-r2"
SLOT="0/${PV%%.*}"
KEYWORDS="-* amd64 x86"

DEPEND="acct-group/video"
RDEPEND="${DEPEND}"

S="${WORKDIR}"

PATCHES=(
	"${FILESDIR}/0001-kernel-5.7.patch"
	"${FILESDIR}/0002-kernel-5.8.patch"
	"${FILESDIR}/0003-kernel-5.9.patch"
	"${FILESDIR}/0004-kernel-5.10.patch"
	"${FILESDIR}/0005-kernel-5.11.patch"
	"${FILESDIR}/0006-kernel-5.14.patch"
	"${FILESDIR}/0007-kernel-5.15.patch"
	"${FILESDIR}/0008-kernel-5.16.patch"
	"${FILESDIR}/0009-kernel-5.17.patch"
	"${FILESDIR}/0010-kernel-5.18.patch"
	"${FILESDIR}/0011-kernel-6.0.patch"
	"${FILESDIR}/0012-kernel-6.2.patch"
	"${FILESDIR}/0013-kernel-6.3.patch"
	"${FILESDIR}/0014-kernel-6.5.patch"
	"${FILESDIR}/0015-kernel-6.6.patch"
	"${FILESDIR}/0016-kernel-6.8.patch"
	"${FILESDIR}/0017-gcc-14.patch"
	"${FILESDIR}/0018-gcc-15.patch"
	"${FILESDIR}/0019-kernel-6.15.patch"
	"${FILESDIR}/0067-fix-os_flush_work_queue-system-wq-warning.patch"
)

src_prepare() {
	default

	# Create stub .cmd file for precompiled nv-kernel.o
	echo "cmd_${S}/kernel/nv-kernel.o := true" > kernel/.nv-kernel.o.cmd
}

src_compile() {
	local modlist=( nvidia=video:kernel )
	local modargs=(
		IGNORE_CC_MISMATCH=yes NV_VERBOSE=1
		SYSOUT="${KV_OUT_DIR}" SYSSRC="${KV_DIR}"
	)
	use amd64 && modargs+=( ARCH=x86_64 )
	use x86 && modargs+=( ARCH=i386 )

	linux-mod-r1_src_compile
}

src_install() {
	local DOCS=()
	local DISABLE_AUTOFORMATTING="yes"
	local DOC_CONTENTS="\
Trusted users should be in the 'video' group to use NVIDIA devices.
You can add yourself by using: gpasswd -a my-user video

See '${EPREFIX}/etc/modprobe.d/nvidia.conf' for modules options."
	readme.gentoo_create_doc

	linux-mod-r1_src_install

	insinto /etc/modprobe.d
	newins "${FILESDIR}"/nvidia.modprobe nvidia.conf
}

pkg_preinst() {
	local g=$(getent group video | cut -d: -f3)
	[[ ${g} =~ ^[0-9]+$ ]] || die "Failed to determine video group id (got '${g}')"
	sed -i "s/@VIDEOGID@/${g}/" "${ED}"/etc/modprobe.d/nvidia.conf || die
}

pkg_postinst() {
	linux-mod-r1_pkg_postinst
	readme.gentoo_print_elog
}
