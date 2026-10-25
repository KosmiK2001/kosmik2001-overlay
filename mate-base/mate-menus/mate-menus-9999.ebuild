# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-menus.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0-r1, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

GNOME2_LA_PUNT="yes"

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="MATE menu system, implementing the F.D.O cross-desktop spec"
LICENSE="GPL-2+ LGPL-2+ LGPL-2.1+"
SLOT="0"
KEYWORDS="**"

IUSE="debug +introspection nls"

COMMON_DEPEND=">=dev-libs/glib-2.50:2
	introspection? ( >=dev-libs/gobject-introspection-1.82.0-r2:= )
"

RDEPEND="${COMMON_DEPEND}"

BDEPEND="
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"
DEPEND="${COMMON_DEPEND}"

src_configure() {
	# Do NOT compile with --disable-debug/--enable-debug=no as it disables API
	# usage checks.
	mate_src_configure \
		--enable-debug=$(usex debug yes minimum) \
		$(use_enable introspection) \
		$(use_enable nls)
}

src_install() {
	mate_src_install

	exeinto /etc/X11/xinit/xinitrc.d/
	newexe "${FILESDIR}/10-xdg-menu-mate-r1" "10-xdg-menu-mate"
}
