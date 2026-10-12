# Copyright 2026 kosmik2001
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Официальный дистрибутив — только .deb (репозиторий download.max.ru).
# MAX собран на Qt6/QtWebEngine, почти все библиотеки бандлятся в
# /usr/share/max/lib64 (Qt6.11, FFmpeg 61, OpenSSL 3, libstdc++); из системы
# нужен только X11/GL-слой + glib + несколько мелочей (список сверен по ldd
# с учётом RPATH=$ORIGIN/../lib64).
MY_PN="MAX"
MY_PV="26.35.1.80662"

DESCRIPTION="MAX Messenger Desktop client (proprietary, Qt6/QtWebEngine)"
HOMEPAGE="https://max.ru/"
SRC_URI="https://download.max.ru/linux/deb/pool/main/m/max/${MY_PN}-${MY_PV}.deb"

LICENSE="all-rights-reserved" # проприетарный клиент, нет явной лицензии
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

# НЕ шиповать и НЕ пересобирать бандловые бинарники: strip ломает
# QtWebEngine/их .so; все ELF — prebuilt.
RESTRICT="strip mirror test"
QA_PREBUILT="*"

BDEPEND="app-arch/dpkg"

RDEPEND="
	app-cdr/cdrtools
	app-crypt/libsecret
	app-arch/bzip2
	app-arch/zstd
	app-misc/ca-certificates
	dev-libs/double-conversion
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libgcrypt:0
	dev-libs/md4c
	dev-libs/wayland
	gnome-base/gsettings-desktop-schemas
	media-libs/fontconfig
	media-libs/freetype
	media-libs/harfbuzz
	media-libs/libglvnd
	media-libs/libpng
	media-libs/libva
	sys-apps/systemd
	sys-apps/util-linux
	sys-libs/zlib
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXScrnSaver
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libvdpau
	x11-libs/xcb-util-cursor
	x11-libs/xcb-util-keysyms
	x11-libs/xcb-util-wm
	x11-themes/hicolor-icon-theme
"

# Qt6-плагины ищут локали/ресурсы относительно бинарника (qt.conf: Prefix=..)
S="${WORKDIR}"

inherit xdg-utils

src_unpack() {
	# deb распаковывается целиком в ${WORKDIR}/usr/{share,max…}
	dpkg-deb -x "${DISTDIR}/${A}" "${S}" || die "dpkg-deb -x failed"
}

src_install() {
	# всё дерево приложения
	insinto /usr/share
	doins -r "${S}/usr/share/max" || die

	# исполняемые файлы (doins ставит 0644 — восстанавливаем +x)
	fperms 0755 \
		/usr/share/max/bin/max \
		/usr/share/max/bin/crashpad_handler \
		/usr/share/max/bin/max-service/bin/max-service

	# симлинк как в postinst deb-пакета
	dosym ../share/max/bin/max /usr/bin/max

	# .desktop, пиксели
	insinto /usr/share/applications
	doins "${S}/usr/share/applications/max.desktop"
	insinto /usr/share/pixmaps
	doins "${S}/usr/share/pixmaps/max.png"

	local size
	for size in 16 24 32 48 64 128 256 512; do
		insinto "/usr/share/icons/hicolor/${size}x${size}/apps"
		doins "${S}/usr/share/icons/hicolor/${size}x${size}/apps/max.png"
	done
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
