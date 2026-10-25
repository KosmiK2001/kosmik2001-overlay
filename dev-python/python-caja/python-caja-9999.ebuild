# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/python-caja.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».
#
# PYTHON_COMPAT расширен до python3_14 по той же причине, что и в
# python-caja-1.28.0-r1: система собрана с единственным python3_14, и
# апстримовый диапазон 3.11..3.13 делает пакет неустанавливаемым.

EAPI=8

MATE_LA_PUNT="yes"

PYTHON_COMPAT=( python3_{11..14} )

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999 (и потребовал
# >=mate-base/mate-common-9999 из BDEPEND).
MATE_BRANCH="1.28"

inherit mate python-single-r1

KEYWORDS="**"

DESCRIPTION="Python bindings for the Caja file manager"
LICENSE="GPL-2+"
SLOT="0"
IUSE="doc"
REQUIRED_USE=${PYTHON_REQUIRED_USE}

RDEPEND="${PYTHON_DEPS}
	>=dev-libs/glib-2.50:2
	$( python_gen_cond_dep 'dev-python/pygobject:3[${PYTHON_USEDEP}]' )
	>=mate-base/caja-1.17.1[introspection]
	>=x11-libs/gtk+-3.22:3
"

BDEPEND="${RDEPEND}
	dev-util/gtk-doc
	dev-build/gtk-doc-am
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
	doc? ( app-text/docbook-xml-dtd:4.1.2 )
"

src_prepare() {
	MATE_FORCE_AUTORECONF="true"

	sed -i "s/\$(PACKAGE)/${PF}/g" examples/Makefile.am || die
	mate_src_prepare
}

src_install() {
	mate_src_install

	# Keep the directory for systemwide extensions.
	keepdir /usr/share/caja-python/extensions/
}
