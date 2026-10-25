# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mozo.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0-r1, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
PYTHON_REQ_USE="xml(+)"

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate python-r1

DESCRIPTION="Mozo menu editor for MATE"
LICENSE="GPL-2+ GPL-3+ LGPL-2+ LGPL-2.1+"

SLOT="0"
KEYWORDS="**"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

COMMON_DEPEND="${PYTHON_DEPS}
	>=dev-python/pygobject-3:3[${PYTHON_USEDEP}]
	>=mate-base/mate-panel-1.28.0
	>=mate-base/mate-menus-1.28.0[introspection]
	x11-libs/gdk-pixbuf:2[introspection]
	>=x11-libs/gtk+-3.12:3[introspection]
"

RDEPEND="${COMMON_DEPEND}
	virtual/libintl
"
DEPEND="${COMMON_DEPEND}
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_prepare() {
	mate_src_prepare
	python_copy_sources
}

src_configure() {
	python_foreach_impl run_in_build_dir mate_src_configure \
		--disable-icon-update
}

src_compile() {
	python_foreach_impl run_in_build_dir default
}

src_test() {
	python_foreach_impl run_in_build_dir emake check
}

src_install() {
	installing() {
		mate_src_install

		# Massage shebang to make python_doscript happy
		sed -e 's:#! '"${PYTHON}:#!/usr/bin/python:" \
			-i mozo || die

		python_doscript mozo
		python_optimize
	}

	python_foreach_impl run_in_build_dir installing
}
