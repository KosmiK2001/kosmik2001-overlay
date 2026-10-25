# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/libmatekbd.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

MATE_LA_PUNT="yes"

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="MATE keyboard configuration library"
LICENSE="GPL-2+ LGPL-2+"
SLOT="0"
KEYWORDS="**"

IUSE="X +introspection test"
RESTRICT="!test? ( test )"

COMMON_DEPEND="
	>=dev-libs/glib-2.50:2
	virtual/libintl
	x11-libs/cairo
	>=x11-libs/gdk-pixbuf-2.24:2
	x11-libs/libX11
	>=x11-libs/libxklavier-5.2:0[introspection?]
	x11-libs/pango
	>=x11-libs/gtk+-3.22:3[introspection?]
	introspection? ( >=dev-libs/gobject-introspection-1.82.0-r2:= )
"

RDEPEND="${COMMON_DEPEND}"

DEPEND="${COMMON_DEPEND}"

BDEPEND="
	dev-util/glib-utils
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_configure() {
	mate_src_configure \
		$(use_with X x) \
		$(use_enable introspection) \
		$(use_enable test tests)
}
