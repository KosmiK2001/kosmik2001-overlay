# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-settings-daemon.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0-r2, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».
# Полка mate-desktop поднята до 1.29.0: master upstream проверяет
# mate-desktop-2.0 >= 1.29.0 (configure.ac), установленной 1.28.2 это
# не хватает, так что live-сборка msd тянет за собой mate-desktop-9999.

EAPI=8

MATE_LA_PUNT="yes"

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="MATE Settings Daemon"
LICENSE="GPL-2+ GPL-3+ HPND LGPL-2+ LGPL-2.1+"
SLOT="0"
KEYWORDS="**"

IUSE="X accessibility debug libnotify policykit pulseaudio rfkill smartcard +sound wayland"

REQUIRED_USE="pulseaudio? ( sound )"

# configure.ac: --enable-wayland (по умолчанию auto) требует gdk/gdkwayland.h,
# wayland-client >= 1.18, wayland-protocols и gtk-layer-shell-0 >= 0.6.
# Включает плагины background/clipboard с Wayland-бэкендами. Флагом делаем
# автодетект явным: иначе wayland молча выключается при отсутствии любого из
# этих пакетов, и «сборка прошла», а под Wayland не работает ничего.

COMMON_DEPEND=">=dev-util/gdbus-codegen-2.80.5-r1
	>=dev-libs/glib-2.50:2
	>=gnome-base/dconf-0.13.4
	>=mate-base/libmatekbd-1.17.0
	>=mate-base/mate-desktop-1.29.0
	media-libs/fontconfig:1.0
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	>=x11-libs/gtk+-3.22:3
	x11-libs/libX11
	x11-libs/libXi
	x11-libs/libXext
	>=x11-libs/libxklavier-5.2
	wayland? (
		>=dev-libs/wayland-1.18
		dev-libs/wayland-protocols
		gui-libs/gtk-layer-shell
		>=x11-libs/gtk+-3.22:3[wayland]
	)
	accessibility? ( >=app-accessibility/at-spi2-core-2.36.0 )
	libnotify? ( >=x11-libs/libnotify-0.7:0 )
	policykit? (
		>=sys-apps/dbus-1.10.0
		>=sys-auth/polkit-0.97
	)
	pulseaudio? (
		>=media-libs/libmatemixer-1.10[pulseaudio]
		media-libs/libpulse
	)
	smartcard? ( >=dev-libs/nss-3.11.2 )
	sound? (
		>=media-libs/libmatemixer-1.10
		|| (
			media-libs/libcanberra-gtk3
			media-libs/libcanberra[gtk3(-)]
		)
	virtual/libintl
	)
"
BDEPEND="
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

RDEPEND="${COMMON_DEPEND}"

DEPEND="${COMMON_DEPEND}
	x11-base/xorg-proto
"

src_configure() {
	mate_src_configure \
		$(use_with X x) \
		$(use_with libnotify) \
		$(use_with sound libcanberra) \
		$(use_with sound libmatemixer) \
		$(use_enable debug) \
		$(use_enable policykit polkit) \
		$(use_enable pulseaudio pulse) \
		$(use_enable rfkill) \
		$(use_enable smartcard smartcard-support) \
		$(use_enable wayland)
}
