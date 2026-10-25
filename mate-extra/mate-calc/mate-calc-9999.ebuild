# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-calc.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0-r2, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».
# Убран патч ::gentoo: mate-calc-1.28.0-mpc-1.4.patch (mp_invert_sign уже исправлен в master).

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="Calculator for MATE"
LICENSE="CC-BY-SA-3.0 GPL-2+"
SLOT="0"
KEYWORDS="**"

COMMON_DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0
	>=dev-libs/glib-2.50:2
	dev-libs/libxml2:2=
	dev-libs/mpc:=
	>=dev-libs/mpfr-4.0.2:=
	>=x11-libs/gtk+-3.22:3
	x11-libs/pango
"

RDEPEND="${COMMON_DEPEND}
	virtual/libintl
"

BDEPEND="${COMMON_DEPEND}
	app-text/yelp-tools
	dev-libs/libxml2
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

