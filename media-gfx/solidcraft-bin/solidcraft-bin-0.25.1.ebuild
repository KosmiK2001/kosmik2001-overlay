# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Upstream names its release artifact after the source package, so the fetch name
# cannot be built from ${PN} here.
MY_PN="solidcraft"
MY_P="${MY_PN}-${PV}-linux-x86_64"

DESCRIPTION="Open-source parametric 3D CAD in pure Rust (prebuilt upstream binary)"
HOMEPAGE="https://github.com/tangency-labs/solidcraft"
SRC_URI="https://github.com/tangency-labs/solidcraft/releases/download/v${PV}/${MY_P}.tar.gz"
S="${WORKDIR}/${MY_P}"

LICENSE="MIT Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

# Nothing to test: the suites live in the source tree (cargo xtask ci) and need a
# GPU path tracer and a wasm target.
# "strip": the binaries arrive pre-stripped from upstream, so portage must not try
# (and must not warn about it) — the same reason www-client/firefox-bin sets it.
RESTRICT="test strip"

# Same list as media-gfx/solidcraft, and for the same reason: the binaries link only
# glibc and libgcc_s, while windowing (X11/Wayland, xkbcommon) and the GPU (Vulkan,
# EGL/GL) are dlopen'd, so portage's ELF scanner cannot find them. Source: upstream
# packaging/linux/nfpm.yaml (deb Depends) plus the runtimeLibs set in flake.nix.
# sys-apps/dbus backs the portal file dialogs and the Secret Service keyring backend.
#
# The block on the source-build package is deliberate: both install the same paths
# (/opt/solidcraft/bin, the /usr/bin symlinks, the desktop/mime/icon/metainfo files),
# so they are alternatives, not co-installables.
RDEPEND="
	!media-gfx/solidcraft:0
	dev-libs/wayland
	x11-libs/libxkbcommon[X]
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcursor
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXext
	sys-apps/dbus
	|| ( media-libs/vulkan-loader media-libs/libglvnd[X] )
"

# No rust, and that is the whole point of the split: cargo.eclass pulls the
# toolchain dependency in unconditionally (rust.eclass sets BDEPEND="${RUST_DEPEND}"
# unless RUST_OPTIONAL), so a `binary` USE flag inside the source ebuild could not
# drop it. A separate -bin package name is how ::gentoo separates the two
# (www-client/firefox-bin), and note that `solidcraft-0.25.1-bin.ebuild` is not a
# legal file name: portage would read the version as 0.25.1-bin.
BDEPEND=""

src_install() {
	local app_id=io.tangencylabs.solidcraft

	# The release tarball is a flat FHS tree (bin/ + share/, no usr/), produced by
	# upstream's packaging/linux/package.sh. Same install layout as the source-build
	# ebuild, so a desktop session cannot tell the two apart.
	exeinto /opt/solidcraft/bin
	doexe bin/solidcraft
	doexe bin/solidcraft-cli
	doexe bin/solvecraft-cli

	# Absolute targets: /usr/bin/x -> ../solidcraft/bin/x would resolve to
	# /usr/solidcraft/bin/x, not to the /opt prefix.
	dosym /opt/solidcraft/bin/solidcraft /usr/bin/solidcraft
	dosym /opt/solidcraft/bin/solidcraft-cli /usr/bin/solidcraft-cli
	dosym /opt/solidcraft/bin/solvecraft-cli /usr/bin/solvecraft-cli

	# Upstream keeps its docs at share/doc/solidcraft; dodoc relocates them into the
	# ${PF} directory portage expects.
	dodoc share/doc/solidcraft/*

	insinto /usr/share/applications
	doins share/applications/${app_id}.desktop

	# Already renamed by upstream (the source tree ships ${app_id}.mime.xml).
	insinto /usr/share/mime/packages
	doins share/mime/packages/${app_id}.xml

	# @VERSION@ and @DATE@ are substituted in the released artifact.
	insinto /usr/share/metainfo
	doins share/metainfo/${app_id}.metainfo.xml

	insinto /usr/share/icons
	doins -r share/icons/hicolor
}

# Refresh the three XDG caches (desktop / mime / icons). Upstream runs ONE
# script for BOTH install and remove (packaging/linux/postinst.sh, wired as
# postinstall AND postremove in nfpm.yaml), so pkg_postinst and pkg_postrm here
# call the same helper. Written inline instead of inheriting xdg-utils.eclass on
# purpose: `inherit cargo xdg-utils` breaks cargo.eclass's EXPORT_FUNCTIONS at
# metadata time (die: cargo_src_unpack is not defined) in this tree, while the
# light -bin ebuild takes xdg-utils happily. The eclass helpers would be tidier
# (xdg_icon_cache_update also prunes stale per-theme caches); this is what works.
_solidcraft_cache_update() {
	if type -P update-desktop-database >/dev/null; then
		update-desktop-database -q /usr/share/applications
	fi
	if type -P update-mime-database >/dev/null; then
		update-mime-database /usr/share/mime
	fi
	if type -P gtk-update-icon-cache >/dev/null; then
		gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor
	fi
}

pkg_postinst() {
	# Same three caches packaging/linux/postinst.sh refreshes.
	_solidcraft_cache_update

	elog "This is upstream's prebuilt binary, not a build of this ebuild. If it trips"
	elog "over the CPU (SIGILL) or the GPU stack here, emerge media-gfx/solidcraft"
	elog "instead: that one compiles from source for this machine."
	elog
	elog "SolidCraft stores agent-chat API keys in the system keychain. On Linux that"
	elog "is the Secret Service over D-Bus, so a provider must be running"
	elog "(gnome-base/gnome-keyring or kde-frameworks/kwallet)."
	elog
	elog "CJK and Arabic UI text falls back to fonts in the system font directories."
	elog "Point SOLIDCRAFT_FONT_DIRS (colon separated) or CRAFT_FONTS_DIR at a font"
	elog "pack to override, e.g. media-fonts/noto-cjk for Japanese/Chinese."
}

pkg_postrm() {
	_solidcraft_cache_update
}