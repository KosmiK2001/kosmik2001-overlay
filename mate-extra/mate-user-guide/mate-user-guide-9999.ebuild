# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-user-guide.
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

DESCRIPTION="User documentation for MATE Desktop"
LICENSE="GPL-2 LGPL-2"
SLOT="0"
KEYWORDS="**"
IUSE="nls"

COMMON_DEPEND="virtual/libintl"

RDEPEND="${COMMON_DEPEND}
	gnome-extra/yelp"

DEPEND="${COMMON_DEPEND}"

BDEPEND="
	app-text/yelp-tools
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_configure() {
	mate_src_configure \
		$(use_enable nls)
}
