# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/eom.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.1, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».
# Убран патч ::gentoo: eom-1.28.1-girepository-2.0-detection.patch (то же самое уже в master).

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit gnome2 mate optfeature

DESCRIPTION="The MATE image viewer"
HOMEPAGE="https://github.com/mate-desktop/eom"
LICENSE="FDL-1.1+ GPL-2+ IJG LGPL-2+"
SLOT="0"
KEYWORDS="**"

IUSE="X debug exif imagemagick +introspection nls jpeg lcms svg tiff xmp"

COMMON_DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0
	>=dev-libs/glib-2.52:2
	>=dev-libs/libpeas-1.8.0:0=[gtk]
	>=dev-libs/libxml2-2:2=
	gnome-base/dconf
	>=mate-base/mate-desktop-${MATE_BRANCH}
	virtual/zlib:=
	x11-libs/cairo
	>=x11-libs/gdk-pixbuf-2.36.5:2[introspection?,jpeg?,tiff?]
	>=x11-libs/gtk+-3.22:3[introspection?]
	x11-libs/libX11
	>=x11-misc/shared-mime-info-0.20
	exif? (
		>=media-libs/libexif-0.6.22
		media-libs/libjpeg-turbo:=
	)
	imagemagick? ( >=media-gfx/imagemagick-6.2.6 )
	introspection? ( >=dev-libs/gobject-introspection-1.82.0-r2:= )
	jpeg? ( media-libs/libjpeg-turbo:= )
	lcms? ( media-libs/lcms:2 )
	svg? ( >=gnome-base/librsvg-2.36.2:2 )
	xmp? ( >=media-libs/exempi-1.99.5:2= )
"

RDEPEND="${COMMON_DEPEND}
	virtual/libintl
"

BDEPEND="${COMMON_DEPEND}
	app-text/yelp-tools
	dev-util/glib-utils
	dev-util/gtk-doc
	dev-build/gtk-doc-am
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_configure() {
	mate_src_configure \
		--enable-thumbnailer \
		$(use_enable debug) \
		$(use_enable introspection) \
		$(use_with X x) \
		$(use_with exif libexif) \
		$(usex imagemagick \
			--without-gdk-pixbuf-thumbnailer \
			--with-gdk-pixbuf-thumbnailer \
		) \
		$(use_with jpeg libjpeg) \
		$(use_with lcms cms) \
		$(use_with svg librsvg) \
		$(use_with xmp)
}

pkg_postinst() {
	gnome2_pkg_postinst
	optfeature "webp support" gui-libs/gdk-pixbuf-loader-webp
}
