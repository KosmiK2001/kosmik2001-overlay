# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-panel.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.7, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».
# Подмодуль mate-panel/mate-submodules для live-версии тянет git-r3
# (в релизном ebuildе его подсовывают отдельным тарбоксом) — поэтому
# src_unpack здесь обычный default.

EAPI=8

MATE_LA_PUNT="yes"

MATE_FORCE_AUTORECONF=true

# Live-пакеты собираются против релизной 1.28-ветки MATE, а не тянут
# за собой весь DE: иначе eclass взял бы MATE_BRANCH=9999.
MATE_BRANCH="1.28"

inherit mate

DESCRIPTION="The MATE panel"
LICENSE="FDL-1.1+ GPL-2+ LGPL-2+"
SLOT="0"
KEYWORDS="**"

IUSE="+X +introspection wayland"

REQUIRED_USE="|| ( X wayland )"

# Wayland-бэкенд в master переехал на libxfce4windowing: configure.ac проверяет
# «gtk-layer-shell-0 wayland-client», затем «libxfce4windowing-0 >= 4.20.2» и при
# --enable-wayland падает с
#   configure: error: Wayland support requires libxfce4windowing-0 >= 4.20.2
# В релизном 1.28 этой зависимости ещё нет — отсюда отличие от ::gentoo.
# XFW используется только в applets/wncklet/wayland-*.c под ENABLE_WAYLAND,
# поэтому зависимость строго под флагом wayland; [wayland] — чтобы у самой XFW
# был собран нужный бэкенд.

COMMON_DEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	>=dev-libs/glib-2.50:2
	>=dev-libs/libmateweather-1.28.0
	dev-libs/libxml2:2=
	>=gnome-base/dconf-0.13.4
	>=gnome-base/dconf-editor-43.0
	>=mate-base/mate-desktop-${MATE_BRANCH}
	>=mate-base/mate-menus-1.28.0
	>=sys-apps/dbus-1.1.2
	>=x11-libs/cairo-1.0.0[X?]
	>=x11-libs/gdk-pixbuf-2.26.0:2
	>=x11-libs/gtk+-3.24.0:3[introspection?]
	x11-libs/libICE
	x11-libs/libSM
	>=x11-libs/libwnck-43.0:3[introspection?]
	>=x11-libs/pango-1.15.4:0[introspection?]
	X? (
		x11-libs/libX11
		x11-libs/libXau
		>=x11-libs/libXrandr-1.3
	)
	introspection? ( >=dev-libs/gobject-introspection-1.82.0-r2:= )
	wayland? (
		gui-libs/gtk-layer-shell
		dev-libs/wayland
		>=xfce-base/libxfce4windowing-4.20.2[wayland]
	)
"

RDEPEND="${COMMON_DEPEND}
	virtual/libintl
"

DEPEND="${COMMON_DEPEND}"

BDEPEND="
	app-text/docbook-xml-dtd:4.1.2
	app-text/yelp-tools
	>=dev-lang/perl-5:=
	dev-util/glib-utils
	dev-util/gdbus-codegen
	dev-util/gtk-doc
	dev-build/gtk-doc-am
	>=sys-devel/gettext-0.19.8
	virtual/pkgconfig
"

src_configure() {
	local myconf=(
		--disable-deprecation-flags
		$(use_enable X x11)
		$(use_enable introspection)
		$(use_enable wayland)
		# Апплеты панели (clock, fish, notification-area, wncklet) по умолчанию
		# собираются out-of-process, а это X11-only: под Wayland панель падает с
		#   "Requested out-of-process applet, which is only supported on X11"
		# и фабрика апплета завершается со статусом 1. In-process сборка
		# работает и на X11, и на Wayland.
		--with-in-process-applets=$(usex wayland all none)
	)

	mate_src_configure \
		--libexecdir="${EPREFIX}"/usr/libexec/mate-applets \
		"${myconf[@]}"
}
