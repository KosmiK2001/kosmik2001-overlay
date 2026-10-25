# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-icon-theme.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="MATE default icon themes"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="**"

COMMON_DEPEND=">=x11-themes/hicolor-icon-theme-0.10"

RDEPEND="${COMMON_DEPEND}"

BDEPEND="${COMMON_DEPEND}
	>=dev-util/intltool-0.40
	>=x11-misc/icon-naming-utils-0.8.7:0
	sys-devel/gettext:*
	virtual/pkgconfig:*"

RESTRICT="binchecks strip"

src_configure() {
	mate_src_configure --enable-icon-mapping
}
