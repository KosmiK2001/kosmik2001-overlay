# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-media.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.1-r2, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="Multimedia related programs for the MATE desktop"
LICENSE="FDL-1.1+ GPL-2+ HPND LGPL-2+"
SLOT="0"
KEYWORDS="**"

IUSE="wayland"

# configure.ac: --enable-wayland (по умолчанию auto) требует gtk-layer-shell-0,
# wayland-client и gdk-wayland-3.0. Флаг заодно включает in-process сборку
# апплета (--enable-in-process), без которой громкость под Wayland не работает:
# configure выводит in-process из значения wayland.

COMMON_DEPEND="
	>=dev-libs/glib-2.50:2
	dev-libs/libxml2:2=
	>=mate-base/mate-panel-1.28.0
	>=mate-base/mate-desktop-${MATE_BRANCH}
	|| (
		media-libs/libcanberra-gtk3
		media-libs/libcanberra[gtk3(-)]
	)
	>=media-libs/libmatemixer-1.28.0
	x11-libs/cairo
	>=x11-libs/gtk+-3.22:3
	x11-libs/pango
	wayland? (
		gui-libs/gtk-layer-shell
		dev-libs/wayland
		>=x11-libs/gtk+-3.22:3[wayland]
	)
"

BDEPEND="${COMMON_DEPEND}
	virtual/libintl
"

DEPEND="${COMMON_DEPEND}
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_configure() {
	mate_src_configure \
		$(use_enable wayland) \
		$(use_enable wayland in-process)
}
