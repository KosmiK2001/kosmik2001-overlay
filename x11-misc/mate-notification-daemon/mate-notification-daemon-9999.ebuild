# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-notification-daemon.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.5, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

MATE_LA_PUNT="yes"

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="MATE Notification daemon"
LICENSE="GPL-2+ GPL-3+"
SLOT="0"
KEYWORDS="**"

IUSE="nls +X wayland"
REQUIRED_USE="|| ( X wayland )"

COMMON_DEPEND=">=app-accessibility/at-spi2-core-2.46.0
	>=dev-libs/glib-2.50:2
	>=dev-libs/libxml2-2.9.0:=
	>=sys-apps/dbus-1
	x11-libs/cairo
	>=x11-libs/gdk-pixbuf-2.22:2
	>=x11-libs/libnotify-0.7
	>=x11-libs/gtk+-3.22:3
	|| (
		media-libs/libcanberra-gtk3
		>=media-libs/libcanberra-0.4[gtk3(-)]
	)
	X? (
		x11-libs/libX11
		>=x11-libs/libwnck-43.0:3
	)
	wayland? ( gui-libs/gtk-layer-shell )
"

RDEPEND="${COMMON_DEPEND}
	!x11-misc/notify-osd
	!x11-misc/notification-daemon
"

DEPEND="${COMMON_DEPEND}
	app-arch/xz-utils
	>=dev-util/gdbus-codegen-2.80.5-r1
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
	mate-base/mate-panel
"

src_configure() {
	mate_src_configure \
		$(use_enable nls) \
		$(use_enable X x11) \
		$(use_enable wayland) \
		$(use_enable wayland in-process)
}

src_install() {
	mate_src_install

	insinto /usr/share/dbus-1/services
	doins "${FILESDIR}/org.freedesktop.Notifications.service"
}
