# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-terminal.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.1, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="The MATE Terminal"
LICENSE="FDL-1.1+ GPL-3+ LGPL-3+"
SLOT="0"
KEYWORDS="**"

COMMON_DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0
	>=dev-libs/glib-2.50:2
	>=gnome-base/dconf-0.13.4
	x11-libs/gdk-pixbuf:2
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/pango
	>=x11-libs/gtk+-3.22:3[X]
	>=x11-libs/vte-0.48:2.91
"

RDEPEND="${COMMON_DEPEND}
	>=mate-base/mate-desktop-${MATE_BRANCH}
	virtual/libintl
"

BDEPEND="${COMMON_DEPEND}
	app-text/rarian
	app-text/yelp-tools
	dev-util/glib-utils
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"
