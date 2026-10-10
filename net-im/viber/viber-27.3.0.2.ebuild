# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature pax-utils unpacker xdg

DESCRIPTION="Free and secure calls and messages to anyone, anywhere"
HOMEPAGE="https://www.viber.com/"
SRC_URI="https://download.cdn.viber.com/cdn/desktop/Linux/${PN}.deb -> ${P}.deb"
S="${WORKDIR}"

LICENSE="viber"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="+tray-toggle +notif-ignore"
RESTRICT="bindist mirror strip"

# Viber бандлит весь свой Qt6 (libQt6*.so.6 в /opt/viber/lib, RUNPATH
# $ORIGIN:$ORIGIN/lib) — системный Qt не нужен. Ниже только ВНЕШНИЕ NEEDED,
# снятые readelf со всех 160 ELF deb-пакета viber-27.3.0.2, со слотами/
# подслотами ::gentoo на 2026-10.
RDEPEND="
	app-accessibility/at-spi2-core:2
	app-arch/brotli:=
	app-arch/bzip2:=
	app-arch/snappy:=
	app-arch/zstd:=
	app-crypt/mit-krb5
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libinput:=
	dev-libs/libxml2:2/16
	dev-libs/libxslt
	dev-libs/nspr
	dev-libs/nss
	dev-libs/openssl:=
	dev-libs/wayland
	media-libs/alsa-lib
	media-libs/fontconfig:1.0
	media-libs/freetype:2
	media-libs/jbigkit:=
	media-libs/libjpeg-turbo:=
	media-libs/libpulse
	media-libs/libva:=
	media-libs/libvorbis
	media-libs/mesa
	media-libs/openjpeg:2/7
	media-libs/opus
	net-libs/gnutls:=
	net-libs/libssh:=
	net-print/cups
	sys-apps/dbus
	sys-devel/gcc:=
	sys-libs/glibc
	sys-libs/zlib:=
	virtual/libudev
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXScrnSaver
	x11-libs/libXtst
	x11-libs/libdrm
	x11-libs/libvdpau
	x11-libs/libxcb:=
	x11-libs/libxkbcommon
	x11-libs/libxkbfile
	x11-libs/libxshmfence
	x11-libs/pango
	x11-libs/xcb-util-image
	x11-libs/xcb-util-keysyms
	x11-libs/xcb-util-renderutil
	x11-libs/xcb-util-wm
"
# В отличие от старых viber-ebuild здесь НЕТ media-video/ffmpeg-compat:58 и
# gstreamer-стека: viber-27.3.0.2 бандлит ffmpeg-6 (libavcodec.so.61) и
# QtMultimedia-плагин в /opt/viber/lib.

BDEPEND="sys-apps/fix-gnustack"

# Проприетарные prebuilt-бинари и библиотеки: весь /opt/viber.
QA_PREBUILT="*"

src_prepare() {
	default

	# Бинарные правки поведения трей-иконки/уведомлений (см.
	# files/viber-binary-patch.py и metadata.xml). Обе замены сохраняют
	# размер файла: QML-блоки вшиты в ресурс с 4-байтным BE-префиксом
	# длины, moc-строки Qt6 фиксируются по смещениям.
	if use tray-toggle || use notif-ignore; then
		local args=()
		use tray-toggle && args+=( --tray-toggle )
		use notif-ignore && args+=( --notif-ignore )
		python3 "${FILESDIR}/viber-binary-patch.py" "${args[@]}" \
			opt/viber/Viber || die "viber-binary-patch.py failed"
	fi

	# Снять execstack с Qt6WebEngineCore. На 27.3.0.2 GNU_STACK уже RW у
	# всех ELF, так что это страховка на случай возврата флага upstream;
	# -f = не падать, если флаг не найден.
	fix-gnustack -f opt/viber/lib/libQt6WebEngineCore.so.6 >/dev/null || die

	# desktop-файл: запуск через обёртку /usr/bin/viber (она включает
	# opt-in workarounds отрисовки), убрать хардкод Path= и абсолютный
	# путь к иконке.
	sed -i \
		-e 's|^Exec=/opt/viber/Viber|Exec=/usr/bin/viber|' \
		-e '/^Path=/d' \
		-e 's|^Icon=.*|Icon=viber|' \
		usr/share/applications/viber.desktop || die "sed viber.desktop"
}

src_install() {
	insinto /opt/viber
	doins -r opt/viber/.
	# doins теряет бит +x
	fperms 0755 /opt/viber/Viber /opt/viber/libexec/QtWebEngineProcess

	# маркер для обёртки: включаем QML_DISABLE_DISK_CACHE только когда
	# трей-патч реально в бинаре (иначе Qt грузит AOT-версию QML и патч мёртв)
	use tray-toggle && touch "${ED}"/opt/viber/.viber-tray-patched

	# обёртка запуска: /etc/viber/viber.conf + qtpaths в PATH
	newbin "${FILESDIR}/viber.sh" viber
	dosym viber /usr/bin/Viber

	insinto /etc/viber
	doins "${FILESDIR}/viber.conf.example"

	# fontconfig-отсев COLRv1-эмодзи (opt-in: VIBER_EMOJI_FIX=1)
	insinto /usr/share/viber
	doins "${FILESDIR}/viber-emoji-fontconf.conf"

	# иконки: scalable + растры из deb
	newicon -s scalable usr/share/icons/hicolor/scalable/apps/Viber.svg viber.svg
	for size in 16 24 32 48 64 96 128 256; do
		newicon -s ${size} "usr/share/viber/${size}x${size}.png" viber.png
	done
	dosym ../icons/hicolor/96x96/apps/viber.png /usr/share/pixmaps/viber.png

	domenu usr/share/applications/viber.desktop
	# алиас, который создаёт postinst официальной упаковки
	dosym viber.desktop /usr/share/applications/com.viber.Viber.desktop

	# Chromium/QtWebEngine нужен mprotect(RWX) для JIT
	pax-mark m "${ED}"/opt/viber/Viber
	pax-mark m "${ED}"/opt/viber/libexec/QtWebEngineProcess
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature "emoji-рендеринг (нужна CBDT-версия NotoColorEmoji; COLRv1 Qt в Viber не рисует)" media-fonts/noto-emoji

	if [[ -z ${ROOT} ]] ; then
		elog "Запуск: /usr/bin/viber (ярлык /usr/bin/Viber — симлинк на него)."
		elog "Opt-in workarounds отрисовки включаются в /etc/viber/viber.conf:"
		elog "  VIBER_FORCE_XCB=1      — X11 вместо Wayland (чёрное/прозрачное окно на nvidia)"
		elog "  VIBER_QSG_BACKEND=...  — opengl|vulkan для Qt Quick RHI"
		elog "  VIBER_SOFTWARE_RENDER=1 — программный рендер Qt Quick (крайняя мера)"
		elog "  VIBER_EMOJI_FIX=1      — отсев COLRv1-эмодзи через fontconfig"
		elog "USE-флаги по умолчанию: tray-toggle (клик по трей-иконке прячет окно),"
		elog "notif-ignore (Viber не реагирует на клик по уведомлениям в системном трее)."
	fi
}
