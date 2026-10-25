# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/engrampa.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.2, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate optfeature

DESCRIPTION="Engrampa archive manager for MATE"
HOMEPAGE="https://mate-desktop.org/ https://github.com/mate-desktop/engrampa"

LICENSE="FDL-1.1+ GPL-2+ LGPL-2+"
SLOT="0"
KEYWORDS="**"
IUSE="caja magic"

DEPEND="
	>=dev-libs/glib-2.50:2
	>=dev-libs/json-glib-0.14
	virtual/libintl
	x11-libs/gdk-pixbuf:2
	>=x11-libs/gtk+-3.22:3[X]
	x11-libs/libSM
	x11-libs/pango
	caja? ( >=mate-base/caja-1.17.1 )
	magic? ( >=sys-apps/file-5.38 )
"
RDEPEND="
	${DEPEND}
	virtual/libintl
"
BDEPEND="
	app-text/yelp-tools
	dev-util/glib-utils
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_configure() {
	mate_src_configure \
		--disable-run-in-place \
		$(use_enable caja caja-actions) \
		$(use_enable magic) \
		--disable-packagekit
}

pkg_postinst() {
	mate_pkg_postinst

	optfeature "Support for 7-zip" app-arch/7zip
	optfeature "Support for ace" app-arch/unace
	optfeature "Support for arj" app-arch/arj
	optfeature "Support for cpio" app-alternatives/cpio
	optfeature "Support for deb" app-arch/dpkg
	optfeature "Support for iso" app-cdr/cdrtools
	optfeature "Support for jar,zip" app-arch/zip app-arch/unzip
	optfeature "Support for lha" app-arch/lha
	optfeature "Support for lzma" app-arch/xz-utils
	optfeature "Support for lzop" app-arch/lzop
	optfeature "Support for rar" app-arch/unrar
	optfeature "Support for rpm" app-arch/rpm
	optfeature "Support for unstuff" app-arch/stuffit
	optfeature "Support for zoo" app-arch/zoo
}
