# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Теневая копия ebuild'а из ::gentoo (dev-python/python-caja-1.28.0) с одной
# правкой: PYTHON_COMPAT расширен до python3_14. Машина пользователя —
# single-target python3.14 (PYTHON_TARGETS/PYTHON_SINGLE_TARGET = python3_14),
# поэтому апстримовый диапазон 3.11..3.13 делает пакет неустанавливаемым:
# REQUIRED_USE="${PYTHON_REQUIRED_USE}" не может быть удовлетворён.
#
# Основание полагать, что 3.14 работает: python-caja — это C-расширение поверх
# pygobject (установлен dev-python/pygobject-3.58.0 с +python_targets_python3_14)
# и girepository-2.0; апстрим в configure.ac требует лишь AM_PATH_PYTHON([3.6])
# и подхватывает python-3.14-embed.pc, который в дереве есть.
#
# Когда апстрим Gentoo поднимет диапазон (см. также PR в gentoo/gentoo), этот
# файл удаляется — он нужен только до апстрима.

EAPI=8

MATE_LA_PUNT="yes"

PYTHON_COMPAT=( python3_{11..14} )

inherit mate python-single-r1

KEYWORDS="amd64 ~arm ~arm64 ~loong ~riscv x86"

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

	# The HTML documentation generation is broken and commented out by upstream.
	#
	#if use doc ; then
	#	insinto /usr/share/gtk-doc/html/nautilus-python # for dev-util/devhelp
	#	doins -r docs/html/*
	#fi
}
