# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/pluma.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.1, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».
# Убран патч ::gentoo: pluma-1.28.1-girepository-detection.patch (проверка libpeas на girepository-2.0 уже в master).

EAPI=8

MATE_LA_PUNT="yes"
PYTHON_COMPAT=( python3_{11..14} )

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit gnome2-utils mate python-single-r1 virtualx

DESCRIPTION="Pluma text editor for the MATE desktop"

LICENSE="FDL-1.1+ GPL-2+ LGPL-2+"
SLOT=0
KEYWORDS="**"
IUSE="+introspection spell test"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RESTRICT="!test? ( test )"

COMMON_DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0
	>=dev-libs/glib-2.50:2
	>=dev-libs/libpeas-1.2.0:0=[gtk]
	>=dev-libs/libxml2-2.5:2=
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	>=x11-libs/gtk+-3.22:3[introspection?]
	>=x11-libs/gtksourceview-4.0.2:4
	x11-libs/libICE
	x11-libs/libX11
	>=x11-libs/libSM-1.0
	x11-libs/pango
	introspection? ( >=dev-libs/gobject-introspection-1.82.0-r2:= )
	spell? (
		>=app-text/enchant-1.6:=
		>=app-text/iso-codes-0.35
	)
"
RDEPEND="${COMMON_DEPEND}
	${PYTHON_DEPS}
	virtual/libintl
"
DEPEND="${COMMON_DEPEND}
	app-text/docbook-xml-dtd:4.1.2
	app-text/yelp-tools
	dev-util/glib-utils
	dev-util/gtk-doc
	dev-build/gtk-doc-am
	>=dev-build/libtool-2.2.6:2
	>=mate-base/mate-desktop-${MATE_BRANCH}[introspection?]
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

MATE_FORCE_AUTORECONF=true

src_prepare() {
	# Test require gvfs sftp fs mounted and schema's installed. Skip this one.
	# https://github.com/mate-desktop/mate-text-editor/issues/33
	sed -e '/+= document-saver/d' -i tests/Makefile.am || die

	mate_src_prepare
}

src_configure() {
	mate_src_configure \
		$(use_enable introspection) \
		$(use_enable spell) \
		$(use_enable test tests)
}

src_test() {
	# FIXME: This should be handled at eclass level.
	"${EPREFIX}/${GLIB_COMPILE_SCHEMAS}" --allow-any-name "${S}/data" || die

	unset DBUS_SESSION_BUS_ADDRESS
	local -x GSETTINGS_SCHEMA_DIR="${S}/data"
	virtx emake check
}
