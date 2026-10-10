# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop optfeature pax-utils unpacker xdg

DESCRIPTION="Free and secure calls and messages to anyone, anywhere (live: всегда свежий бинарь с CDN)"
HOMEPAGE="https://www.viber.com/"
# SRC_URI пуст: upstream публикует только по плавающему URL .../Linux/viber.deb
# (версионизированных путей на CDN нет, отдаёт 403 — проверено). Поэтому
# дистиль скачиваем вручную в src_unpack, а Portage не знает о нём ничего.
SRC_URI=""
VIBER_LIVE_URI="https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb"
S="${WORKDIR}"

LICENSE="viber"
SLOT="0"
KEYWORDS="**"
IUSE="+tray-toggle +notif-ignore"
# live = сеть в фазе unpack даже при FEATURES=network-sandbox (portage
# package/ebuild/doebuild.py:243) — без этого флага wget упрётся в песочницу.
PROPERTIES="live"
RESTRICT="bindist mirror strip"

# RDEPEND снят с viber-27.3.0.2 (readelf со всех 160 ELF deb-пакета). Viber
# бандлит весь свой Qt6 в /opt/viber/lib (RUNPATH $ORIGIN:$ORIGIN/lib), так что
# системный Qt не нужен. ВНИМАНИЕ: live-бинарь может сменить набор внешних
# NEEDED — Portage об этом не узнает сам; при странностях запуска
# (`ld.so: cannot open ...`) переснимите список с нового deb.
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

BDEPEND="
	net-misc/wget
	sys-apps/fix-gnustack
"

# Проприетарные prebuilt-бинари и библиотеки: весь /opt/viber.
QA_PREBUILT="*"

src_unpack() {
	# Каждый build качается заново: в этом и смысл live-версии (свежий бинарь
	# на каждой сборке). Кэшировать в ${DISTDIR} нельзя — там портнадж
	# создаёт root-owned симлинк, а фазы идут под userpriv (проверено:
	# wget -O ${DISTDIR}/... -> "Отказано в доступе").
	#
	# FETCHCOMMAND здесь не используется: Portage вырезает его из окружения
	# ebuild (special_env_vars.environ_filter), в фазе он пуст — проверено.
	# Поэтому wget напрямую; прокси берётся из HTTP(S)_PROXY окружения.
	einfo "Свежая закачка $(basename "${VIBER_LIVE_URI}") ..."
	wget --passive-ftp -T 60 -t 3 -O "${T}/viber.deb" \
		"${VIBER_LIVE_URI}" || die "wget ${VIBER_LIVE_URI}"

	local head
	head=$(wget -S --spider -T 60 "${VIBER_LIVE_URI}" 2>&1 \
		| sed -n 's/^ *[LR]ast-[Mm]odified: //Ip' | tr -d '\r' | head -1)
	[[ -n ${head} ]] && einfo "CDN Last-Modified: ${head}"

	# реальная версия из control deb-пакета (PV=9999 её не содержит)
	local ver
	ver=$(bsdtar -xOf "${T}/viber.deb" 'control.tar.*' 2>/dev/null \
		| bsdtar -xOf - ./control 2>/dev/null \
		| sed -n 's/^Version: //p' | head -1)
	ver=${ver:-unknown}
	einfo "Версия Viber в скачанном deb: ${ver}"
	printf '%s\n' "${ver}" > "${T}/viber_version" || die

	unpack_deb "${T}/viber.deb" || die "unpack_deb"
}

src_prepare() {
	default

	# Бинарные правки поведения трей-иконки/уведомлений. В live-режиме патчи
	# мягкие (--soft): если upstream переписал QML/moc-строки, патч
	# пропускается с предупреждением, а сборка продолжается — иначе любой
	# релиз Viber ломал бы установку. Проверка размера сохранена.
	if use tray-toggle || use notif-ignore; then
		local args=( --soft )
		use tray-toggle && args+=( --tray-toggle )
		use notif-ignore && args+=( --notif-ignore )
		# rc=2 (--soft) = паттернов не нашли: сборка продолжается, но
		# трей-поведение остаётся апстримным — говорим об этом явно.
		python3 "${FILESDIR}/viber-binary-patch.py" "${args[@]}" \
			opt/viber/Viber
		case $? in
			0) einfo "Бинарные патчи применены" ;;
			2) ewarn "Бинарные патчи ПРОПУЩЕНЫ: апстрим переписал QML/moc —" \
				ewarn "поведение трей-иконки/уведомлений как у upstream" ;;
			*) die "viber-binary-patch.py failed" ;;
		esac
	fi

	# Снять execstack с Qt6WebEngineCore (страховка: на 27.3.0.2 GNU_STACK
	# уже RW; -f = не падать, если флаг не найден).
	fix-gnustack -f opt/viber/lib/libQt6WebEngineCore.so.6 >/dev/null || die

	# desktop-файл: запуск через обёртку /usr/bin/viber (opt-in workarounds
	# отрисовки), убрать хардкод Path= и абсолютный путь к иконке.
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

	# реальная версия рядом с бинарём (PV=9999 её не несёт)
	newins "${T}/viber_version" .viber-version

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
		local ver=$(cat /opt/viber/.viber-version 2>/dev/null)
		elog "Установлена live-сборка net-im/viber: реальная версия ${ver:-unknown}"
		elog "(PV=9999 — каждый emerge качает бинарь с CDN заново)."
		elog "Запуск: /usr/bin/viber (ярлык /usr/bin/Viber — симлинк на него)."
		elog "Opt-in workarounds отрисовки включаются в /etc/viber/viber.conf:"
		elog "  VIBER_FORCE_XCB=1      — X11 вместо Wayland (чёрное/прозрачное окно на nvidia)"
		elog "  VIBER_QSG_BACKEND=...  — opengl|vulkan для Qt Quick RHI"
		elog "  VIBER_SOFTWARE_RENDER=1 — программный рендер Qt Quick (крайняя мера)"
		elog "  VIBER_EMOJI_FIX=1      — отсев COLRv1-эмодзи через fontconfig"
		elog "USE-флаги по умолчанию: tray-toggle (клик по трей-иконке прячет окно),"
		elog "notif-ignore (Viber не реагирует на клик по уведомлениям в системном трее)."
		use tray-toggle || use notif-ignore || \
			ewarn "Оба USE-флага патчей выключены — поведение трей-иконки как у upstream."
	fi
}
