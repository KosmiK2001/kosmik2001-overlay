# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-applets.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.1, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="Applets for the MATE Desktop and Panel"
LICENSE="CC-BY-SA-3.0 FDL-1.1+ GPL-2+ GPL-3+ LGPL-2+"
SLOT="0"
KEYWORDS="**"

IUSE="X +cpupower in-process netlink policykit +upower"

# in-process: собрать апплеты внутрь процесса панели (--enable-in-process).
# Требуется под Wayland: out-of-process апплеты там не поддерживаются вообще
# (libmate-panel-applet: «only supported on X11»), фабрика падает со статусом 1.
# На X11 in-process тоже работает — теряется только изоляция падений.

REQUIRED_USE="policykit? ( cpupower )"

COMMON_DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	>=dev-libs/dbus-glib-0.74
	>=dev-libs/glib-2.50:2
	>=dev-libs/libmateweather-1.28.0
	>=dev-libs/libxml2-2.5:2=
	>=gnome-base/libgtop-2.12.0:2=
	>=gnome-extra/gucharmap-3.0:2.90
	>=mate-base/mate-panel-1.28.0
	>=net-wireless/wireless-tools-28_pre9:0
	>=sys-apps/dbus-1.10.0
	x11-libs/gdk-pixbuf:2
	>=x11-libs/gtk+-3.22:3
	>=x11-libs/libnotify-0.7
	x11-libs/libX11
	>=x11-libs/libwnck-3.0:3
	x11-libs/pango
	cpupower? (
		sys-power/cpupower
		policykit? ( >=sys-auth/polkit-0.97:0 )
	)
	netlink? (
		dev-libs/libnl:3
	)
	upower? ( >=sys-power/upower-0.99.8 )
"

RDEPEND="${COMMON_DEPEND}
	mate-base/caja
	>=mate-base/mate-desktop-${MATE_BRANCH}
	>=mate-base/mate-settings-daemon-1.28.0
	virtual/libintl
"

BDEPEND="${COMMON_DEPEND}
	app-text/docbook-xml-dtd:4.3
	app-text/rarian
	app-text/yelp-tools
	dev-libs/libxslt
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_configure() {
	local myconf=(
		$(use_with X x)
		$(use_with netlink nl)
		$(use_enable policykit polkit)
		$(use_with upower)
		$(use_enable in-process)
	)

	# configure.ac logic is a little hinky
	# and ignores --enable flags for cpufreq
	use cpupower || myconf+=( --disable-cpufreq )

	mate_src_configure \
		--libexecdir="${EPREFIX}"/usr/libexec/mate-applets \
		"${myconf[@]}"
}

src_test() {
	unset DBUS_SESSION_BUS_ADDRESS
	emake check
}

src_install() {
	mate_src_install

	local APPLETS=(
		accessx-status battstat charpick command cpufreq drivemount
		geyes mateweather multiload netspeed stickynotes
		timerapplet trashapplet
	)

	for applet in "${APPLETS[@]}"; do
		docinto "${applet}"

		for d in AUTHORS ChangeLog NEWS README README.themes TODO; do
			[[ -s "${applet}/${d}" ]] && dodoc "${applet}/${d}"
		done
	done
}
