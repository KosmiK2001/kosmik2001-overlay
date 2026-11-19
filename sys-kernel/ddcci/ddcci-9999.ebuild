EAPI=8

inherit git-r3 linux-mod-r1

EGIT_REPO_URI="https://gitlab.com/ddcci-driver-linux/ddcci-driver-linux.git"

DESCRIPTION="DDC/CI kernel drivers: ddcci bus driver and ddcci-backlight"
HOMEPAGE="https://gitlab.com/ddcci-driver-linux/ddcci-driver-linux"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""

# Local patches make the drivers usable on the proprietary nVidia i2c
# adapters: bytewise SMBus writes, retried reads, tolerant identification and
# capability parsing, and a probe that does not abort when VCP 0x6b is
# unsupported (this monitor only implements 0x10).
PATCHES=( "${FILESDIR}/${PN}-nvidia-i2c.patch" )

CONFIG_CHECK="I2C"

src_compile() {
	local modlist=(
		"ddcci=extra:ddcci"
		"ddcci-backlight=extra:ddcci-backlight"
	)
	# The upstream Makefiles take the build directory from `uname -r`, so the
	# modules always come out for the RUNNING kernel no matter what KERNEL_DIR
	# says. linux-mod-r1 installs into ${KV} (the selected sources), and the
	# sanity check then aborts the merge with "module and source version
	# mismatch". Override KDIR on the make command line - the Makefile uses a
	# plain `:=`, which a command-line variable overrides. KV_OUT_DIR is the
	# build tree the eclass wants here, so out-of-source builds keep working.
	local modargs=( "KDIR=${KV_OUT_DIR}" )
	linux-mod-r1_src_compile
}

pkg_postinst() {
	linux-mod-r1_pkg_postinst

	elog "On kernels 6.8 and newer the driver cannot auto-probe displays."
	elog "Create the device for the DDC/CI address of the monitor, e.g.:"
	elog "    echo ddcci 0x37 > /sys/bus/i2c/devices/i2c-3/new_device"
	elog ""
	elog "Options this hardware needs (nVidia i2c adapters):"
	elog "    options ddcci delay=150 force_bytewise=1"
}
