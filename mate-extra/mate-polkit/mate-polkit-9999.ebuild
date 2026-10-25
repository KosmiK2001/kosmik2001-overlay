# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-polkit.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.1-r2, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».
# Убран патч ::gentoo: mate-polkit-1.27.1-configure.patch ('==' -> '=' уже в master).

EAPI=8

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="A MATE specific DBUS service that is used to bring up authentication dialogs"
LICENSE="LGPL-2"
SLOT="0"
KEYWORDS="**"

IUSE="accountsservice appindicator"

COMMON_DEPEND="x11-libs/gdk-pixbuf:2
	virtual/libintl:0
	>=x11-libs/gtk+-3.22.0:3[X]
	appindicator? ( dev-libs/libayatana-appindicator )"

RDEPEND="${COMMON_DEPEND}
	>=dev-libs/glib-2.50:2
	>=sys-auth/polkit-0.102[daemon(+)]
	accountsservice? ( sys-apps/accountsservice )"

BDEPEND="${COMMON_DEPEND}
	dev-util/gtk-doc
	dev-build/gtk-doc-am
	>=dev-util/intltool-0.35
	sys-devel/gettext
	>=dev-build/libtool-2.2.6
	virtual/pkgconfig"

src_configure() {
	mate_src_configure \
		--disable-static \
		$(use_enable accountsservice) \
		$(use_enable appindicator)
}
