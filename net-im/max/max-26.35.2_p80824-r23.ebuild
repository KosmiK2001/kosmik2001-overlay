# Copyright 2026 kosmik2001
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# MAX собран на Qt6/QtWebEngine, почти все библиотеки бандлятся в
# /opt/max/lib64 (Qt6.11, FFmpeg 61, OpenSSL 3, libstdc++, своя libsecret);
# список ниже сверен по трём источникам: NEEDED главного бинаря (11 системных
# soname), поздние dlopen из lib64/*.so (GTK-тема/диалоги, NSS для WebEngine,
# pulse/alsa, EGL/GBM, ibus) и Depends официального .deb / Requires
# официального RPM-репозитория (download.max.ru/linux/rpm/el/9/x86_64).
#
# Установка в /opt/max (а не /usr/share): в бинарях нет жёстко зашитых
# абсолютных путей, qt.conf относительный (Prefix=..), RPATH относительный —
# перенос безопасен (проверено strings -a по всем ELF пакета). Официальные
# пакеты кладут то же дерево в /usr/share/max и делают /usr/bin/max через
# update-alternatives (postinst) — у нас единая обёртка, см. src_install.
#
# USE="jail-net" (по умолчанию ВЫКЛ): /usr/bin/max становится обёрткой,
# которая при наличии маркера /etc/max/jail-net запускает приложение в
# изолированном окружении /usr/libexec/max-jail/max_jail.sh (собственный
# netns с единственным default-route, DNS-allowlist 77.88.8.8/8.8.8.8/
# 9.9.9.9/1.1.1.1, маски ФС, hidepid=2, env -i без *_proxy). Маркер и
# лаунчер ставятся ТОЛЬКО с этим флагом.
# qt_stack_build (по умолчанию ВЫКЛ): собрать Qt 6.11.0 из исходников
# (qtbase-6.11.0 + qtsvg-6.11.0) ПРЯМЫМ cmake/ninja внутри src_compile и
# подложить собранные libQt6* вместо вендорских в /opt/max (src_install).
# Никакого хелпера qt-debundle.sh и никаких вложенных ebuild — сборка идёт
# в ${WORKDIR} под sandbox+userpriv (проверено sand-пробой 2026-10-14),
# в систему пакеты НЕ ставятся, системный Qt 6.11.2 не затрагивается.
# Приватный ABI (QtPrivate_6_11_0) обязан совпасть с вендорскими модулями —
# поэтому НИКАКИХ патчей. Время: qtbase ~7 мин на 32 ядрах (ccache),
# qtsvg ~1 мин. Откат: emerge -1 net-im/max (без флага) — deb вернёт вендорские.
MY_PN="MAX"
MY_PV="26.35.2.80824"
QT_URI_BASE="https://download.qt.io/official_releases/qt/6.11/6.11.0/submodules"
SRC_URI="https://download.max.ru/linux/deb/pool/main/m/max/${MY_PN}-${MY_PV}.deb"
# USE-условный SRC_URI (PMS-синтаксис: флаг? ( uri )): тарболы Qt тянутся
# только при qt_stack_build, иначе emerge не требует их в DISTDIR.
SRC_URI+=" qt_stack_build? ( ${QT_URI_BASE}/qtbase-everywhere-src-6.11.0.tar.xz ${QT_URI_BASE}/qtsvg-everywhere-src-6.11.0.tar.xz )"

DESCRIPTION="MAX Messenger Desktop client (proprietary, Qt6/QtWebEngine)"
HOMEPAGE="https://max.ru/"

LICENSE="all-rights-reserved" # проприетарный клиент, нет явной лицензии
SLOT="0"
KEYWORDS="~amd64"
IUSE="jail-net qt_stack_build"

# qt_stack_build (по умолчанию ВЫКЛ): собрать Qt 6.11.0 из исходников
# (dev-qt/qtbase-6.11.0 + dev-qt/qtsvg-6.11.0 из этого же оверлея) и подложить
# собранные libQt6* вместо вендорских в /opt/max. Сборка запускается в
# pkg_postinst (там нет sandbox'а), идёт через ebuild-фазы в /var/tmp/portage —
# в систему пакеты НЕ ставятся, системный Qt 6.11.2 не затрагивается.
# Время: qtbase ~7 мин на 32 ядрах (ccache), qtsvg ~1 мин. Повторный emerge
# с флагом переиспользует готовый image (быстро). См. Qt-debundle в
# /usr/libexec/max-debundle/README.debundle.md.

# НЕ шиповать и НЕ пересобирать бандловые бинарники: strip ломает
# QtWebEngine/их .so; все ELF — prebuilt.
RESTRICT="strip mirror test"
QA_PREBUILT="*"

BDEPEND="
	app-arch/dpkg
	qt_stack_build? (
		app-accessibility/at-spi2-core
		dev-build/cmake
		dev-build/ninja
		dev-libs/wayland
		dev-util/vulkan-headers
		dev-util/wayland-scanner
		media-libs/fontconfig
		media-libs/freetype
		media-libs/harfbuzz
		media-libs/libglvnd
		media-libs/libjpeg-turbo
		media-libs/libpng
		x11-base/xorg-proto
		x11-libs/libICE
		x11-libs/libSM
		x11-libs/libX11
		x11-libs/libxcb
		x11-libs/libxkbcommon
		x11-libs/xcb-util-cursor
		x11-libs/xcb-util-image
		x11-libs/xcb-util-keysyms
		x11-libs/xcb-util-renderutil
		x11-libs/xcb-util-wm
	)
"

RDEPEND="
	app-accessibility/at-spi2-core
	app-arch/bzip2
	app-arch/zstd
	app-crypt/libsecret
	app-misc/ca-certificates
	dev-libs/double-conversion
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libgcrypt:0
	dev-libs/md4c
	dev-libs/nspr
	dev-libs/nss
	dev-libs/openssl
	dev-libs/wayland
	gnome-base/gsettings-desktop-schemas
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/harfbuzz
	media-libs/libglvnd
	media-libs/libpng
	media-libs/libpulse
	media-libs/libva
	media-libs/mesa
	media-libs/vulkan-loader
	sys-apps/dbus
	sys-apps/systemd
	sys-apps/xdg-desktop-portal
	sys-apps/util-linux
	sys-libs/zlib
	x11-libs/gtk+:3
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXaw
	x11-libs/libXres
	x11-libs/libXScrnSaver
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libvdpau
	x11-libs/xcb-util-cursor
	x11-libs/xcb-util-keysyms
	x11-libs/xcb-util-wm
	x11-themes/hicolor-icon-theme
	gnome-base/gnome-keyring
	jail-net? (
		app-admin/sudo
		net-firewall/iptables
		sys-apps/iproute2
		sys-libs/libcap
		x11-apps/xhost
	)
"

# Qt6-плагины ищут локали/ресурсы относительно бинарника (qt.conf: Prefix=..)
S="${WORKDIR}"

inherit xdg-utils

src_unpack() {
	# ВАЖНО: src_unpack переопределён целиком — default_src_unpack не вызываем,
	# иначе 311 МБ .deb зря скопируется в ${WORKDIR} (портаж не знает .deb и
	# просто копирует). Всё распаковываем вручную.
	local qt_tar
	if use qt_stack_build; then
		for qt_tar in qtbase-everywhere-src-6.11.0.tar.xz qtsvg-everywhere-src-6.11.0.tar.xz; do
			[ -e "${DISTDIR}/${qt_tar}" ] || die "нет ${qt_tar} в DISTDIR"
			tar -xf "${DISTDIR}/${qt_tar}" -C "${WORKDIR}" || die "распаковка ${qt_tar}"
		done
	fi
	# дерево приложения из deb
	dpkg-deb -x "${DISTDIR}/${MY_PN}-${MY_PV}.deb" "${S}" || die "dpkg-deb -x failed"
	# контроль: dpkg-deb -x молчит при успехе, но падает без сообщения — проверим явно
	[ -d "${S}/usr/share/max" ] || die "deb не распаковался в ${S}/usr/share/max"
}

# Сборка Qt in-tree (USE=qt_stack_build): qtbase 6.11.0 ПРЯМЫМ cmake/ninja в
# ${WORKDIR}/qtbase-build, затем qtsvg 6.11.0 ПРОТИВ stage-копии qtbase.
# Никаких вложенных ebuild — только cmake/ninja (проверено sand-пробой
# 2026-10-14: sandbox+userpriv+network-sandbox не мешают; без qt6-build eclass
# приватный ABI маркируется ровно от версии qtbase — QtPrivate_6_11_0).
qt_build_stack() {
	local qtbase_src="${WORKDIR}/qtbase-everywhere-src-6.11.0"
	local qtbase_build="${WORKDIR}/qtbase-build"

	einfo "Сборка qtbase-6.11.0 (9 модулей: Core Gui Network Dbus Widgets Xml Concurrent OpenGL XcbQpa)"
	cmake -S "${qtbase_src}" -B "${qtbase_build}" -G Ninja \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_INSTALL_LIBDIR=lib64 \
		-DQT_BUILD_EXAMPLES=OFF \
		-DQT_BUILD_TESTS=OFF \
		-DQT_BUILD_BENCHMARKS=OFF \
		-DQT_BUILD_DOCS=OFF \
		-DBUILD_WITH_PCH=OFF \
		-DQT_FEATURE_sql=OFF \
		-DQT_FEATURE_testlib=OFF \
		-DQT_FEATURE_concurrent=ON \
		-DQT_FEATURE_dbus=ON \
		-DQT_FEATURE_gui=ON \
		-DQT_FEATURE_network=ON \
		-DQT_FEATURE_xml=ON \
		-DQT_FEATURE_widgets=ON \
		-DQT_FEATURE_opengl=ON \
		-DINPUT_opengl=desktop \
		-DQT_FEATURE_xcb=ON \
		-DQT_FEATURE_wayland=ON \
		-DQT_FEATURE_vulkan=ON \
		-DQT_FEATURE_accessibility=ON \
		|| die "qtbase cmake failed"
	ninja -C "${qtbase_build}" || die "qtbase ninja failed"
	for l in Core Gui Network DBus Widgets Xml Concurrent OpenGL XcbQpa; do
		[ -e "${qtbase_build}/lib/libQt6${l}.so.6.11.0" ] || die "libQt6${l} не собралась"
	done
	einfo "qtbase: все 9 модулей собраны, QtPrivate-ABI=6_11_0"

	# stage-установка qtbase НЕ нужна: cmake-конфиги Qt6* и moc лежат в
	# build-дереве (build/lib/cmake/Qt6*, build/libexec/moc) — qtsvg
	# конфигурируется прямо против них (проверено PROBE2)
	[ -d "${qtbase_build}/lib/cmake/Qt6" ] || die "нет cmake/Qt6 в build-дереве"

	einfo "Сборка qtsvg-6.11.0 против build-дерева qtbase"
	cmake -S "${WORKDIR}/qtsvg-everywhere-src-6.11.0" -B "${WORKDIR}/qtsvg-build" -G Ninja \
		-DQt6_DIR="${qtbase_build}/lib/cmake/Qt6" \
		-DQt6Core_DIR="${qtbase_build}/lib/cmake/Qt6Core" \
		-DQt6CorePrivate_DIR="${qtbase_build}/lib/cmake/Qt6CorePrivate" \
		-DQt6CoreTools_DIR="${qtbase_build}/lib/cmake/Qt6CoreTools" \
		-DQt6Gui_DIR="${qtbase_build}/lib/cmake/Qt6Gui" \
		-DQt6GuiTools_DIR="${qtbase_build}/lib/cmake/Qt6GuiTools" \
		-DQt6Widgets_DIR="${qtbase_build}/lib/cmake/Qt6Widgets" \
		-DQt6WidgetsTools_DIR="${qtbase_build}/lib/cmake/Qt6WidgetsTools" \
		-DCMAKE_C_COMPILER=/usr/bin/gcc -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
		-DCMAKE_INSTALL_PREFIX="${WORKDIR}/qtsvg-install" -DCMAKE_BUILD_TYPE=Release \
		-DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DCMAKE_CXX_FLAGS="-O2" \
		|| die "qtsvg cmake failed"
	ninja -C "${WORKDIR}/qtsvg-build" || die "qtsvg ninja failed"
	ninja -C "${WORKDIR}/qtsvg-build" install >/dev/null 2>&1 || true
	# qtsvg install кладёт либы в lib/ (а не lib64/) — как в PROBE2
	[ -e "${WORKDIR}/qtsvg-install/lib/libQt6Svg.so.6.11.0" ] \
		|| die "libQt6Svg не установилась"
	nm -D "${WORKDIR}/qtsvg-install/lib/libQt6Svg.so.6.11.0" 2>/dev/null | grep -q QtPrivate_6_11_0 \
		|| die "qtsvg собран против чужого qtbase (маркер не 6_11_0)"
	einfo "qtsvg: QtPrivate_6_11_0 OK"
}

# src_compile: если qt_stack_build — собрать Qt (см. qt_build_stack выше)
src_compile() {
	if use qt_stack_build; then
		qt_build_stack
	fi
}

# src_install: подложить собранные libQt6* поверх вендорских в ${D}/opt/max/lib64
# (вызывается из src_install, где ${ED} уже создан; build-дерево из src_compile)
qt_deploy_stack() {
	local qtbase_build="${WORKDIR}/qtbase-build"
	einfo "Подложка собранных libQt6 в ${ED}/opt/max/lib64"
	local l
	for l in Core Gui Network DBus Widgets Xml Concurrent OpenGL XcbQpa; do
		cp -P "${qtbase_build}/lib/libQt6${l}.so.6.11.0" "${ED}/opt/max/lib64/" || die "cp libQt6${l}"
		# симлинки .so.6 / .so — сверх тех, что в deb (там только .so.6 и .so.6.11.0)
		ln -sf "libQt6${l}.so.6.11.0" "${ED}/opt/max/lib64/libQt6${l}.so.6"
		if ! [ -e "${D}/opt/max/lib64/libQt6${l}.so" ]; then
			ln -sf "libQt6${l}.so.6" "${ED}/opt/max/lib64/libQt6${l}.so"
		fi
	done
	cp -P "${WORKDIR}/qtsvg-install/lib/libQt6Svg.so.6.11.0" "${ED}/opt/max/lib64/" || die "cp libQt6Svg"
	ln -sf "libQt6Svg.so.6.11.0" "${ED}/opt/max/lib64/libQt6Svg.so.6"
	if ! [ -e "${D}/opt/max/lib64/libQt6Svg.so" ]; then
		ln -sf "libQt6Svg.so.6" "${ED}/opt/max/lib64/libQt6Svg.so"
	fi
	einfo "Вендорские Qt-либы заменены собранными (откат: emerge -1 без флага)"
}

src_install() {
	# всё дерево приложения: deb несёт usr/share/max -> ставим в /opt/max
	insinto /opt
	doins -r "${S}/usr/share/max" || die

	# Дебандинг (проверено swap-тестами 2026-10-13: вынос .so -> запуск ->
	# сверка лога с бейзлайном -> возврат; см. max-internals.md §10):
	#  - libsecret: системная app-crypt/libsecret-0.21.7 (тот же SONAME);
	#  - libssl/libcrypto: системный dev-libs/openssl-3.5.8. НЕ ГОСТ (у бандла
	#    был), но на публичном TLS-стеке макс поведенчески идентичен
	#    (сверено A/B); выигрыш — системные апдейты безопасности.
	# НЕ трогаем Qt: приватный ABI (QtPrivate_6_11_0 в бандле vs 6_11_2 в
	# системе) несовместим даже между патч-релизами — любая подмена Qt-либы
	# даёт "undefined symbol ... Qt_6_PRIVATE_API" (проверено на всех 10);
	# Concurrent/Xml формально грузятся, но создают ДВА Qt-рантайма в одном
	# процессе — не делаем.
	rm -f "${D}"/opt/max/lib64/libsecret-1.so.0* \
		"${D}"/opt/max/lib64/libssl.so.3* \
		"${D}"/opt/max/lib64/libcrypto.so.3* || die

	# max-service (313 МБ, RPC-сервер звонков) несёт СВОЙ бандловый стек в
	# bin/max-service/lib64 (~200 .so). Он СТАРШЕ системного (доказано r19:
	# без вычистки сервис падает при загрузке каскадом undefined symbol —
	# systemd 0.23.0 без LIBSYSTEMD_251 для libmount, freetype 6.16.1 без
	# FT_Get_Paint, harfbuzz 10.7.5 без hb_ot_layout_table_select_script...).
	# RPATH $ORIGIN/../lib64 заставляет бандл перекрывать системные либы.
	# Вычищаем ВСЕ дубли системных soname (список снят с реальной установки
	# 2026-10-14; 103 файла/симлинка = 52 префикса): сервис подхватит
	# системные версии и поднимется (проверено: RPC port, клиент получил
	# camera/mic/speaker sets, state=Running). Qt-стек и crypto/ssl НЕ трогаем.
	rm -f "${D}"/opt/max/bin/max-service/lib64/"libSM.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libasound.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libasyncns.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libatk-1.0.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libatk-bridge-2.0.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libatspi.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libbz2.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libcairo-gobject.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libcairo.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libcap.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libdbus-1.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libdrm.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libepoxy.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libexpat.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libfontconfig.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libfreetype.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libfribidi.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgbm.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgcc_s.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgcrypt.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgdk-3.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgdk_pixbuf-2.0.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgpg-error.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgraphite2.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgsm.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libgtk-3.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libharfbuzz.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"liblz4.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"liblzma.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libnotify.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libogg.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpango-1.0.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpangocairo-1.0.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpangoft2-1.0.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpcre2-16.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpcre2-32.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpcre2-8.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpixman-1.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpng16.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libpulse.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libsndfile.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libstdc++.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libsystemd.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libuuid.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libvorbis.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libvorbisenc.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libwayland-client.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libwayland-cursor.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libwayland-egl.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libwayland-server.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libxcb-cursor.so"* \
		"${D}"/opt/max/bin/max-service/lib64/"libz.so"* || die

	# исполняемые файлы (doins ставит 0644 — восстанавливаем +x)
	fperms 0755 \
		/opt/max/bin/max \
		/opt/max/bin/crashpad_handler \
		/opt/max/bin/max-service/bin/max-service

	# Точка запуска — обёртка /usr/bin/max. БЕЗ USE="jail-net" в ней только
	# минимум, без которого приложение не стартует (живая шина + runtime-dir
	# + уход из мёртвого cwd); ветка джейла добавляется исключительно при
	# jail-net, чтобы обычный пакет не содержал ссылок на max_jail.sh.
	dodir /usr/bin
	{
		echo '#!/bin/sh'
		if use jail-net; then
			cat <<'JAIL'
# USE="jail-net": маркер включает изолированный запуск
if [ -f /etc/max/jail-net ]; then
	exec sudo -n /usr/libexec/max-jail/max_jail.sh --x11 --dbus -- /opt/max/bin/max "$@"
fi
JAIL
		fi
		cat <<'BASE'
# Живая сессионная шина + runtime-dir: всегда берём systemd-user-bus, если она
# существует — в ssh/старых сессиях DBUS_SESSION_BUS_ADDRESS может указывать на
# мёртвую шину, а приложению нужен живой Secret Service (launch.cpp:102 — иначе
# Fatal "libsecret unavailable"; проверено: без XDG_RUNTIME_DIR тоже падает).
if [ -S "/run/user/$(id -u)/bus" ]; then
	export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi
if [ -d "/run/user/$(id -u)" ]; then
	export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
# Амнезия-фикс: MAX хранит ключ SQLCipher-БД в keyring-коллекции login; без неё
# база удаляется каждый запуск и вход сбрасывается (см. max-internals.md §5).
# На этой машине PAM не передаёт пароль (вход без пароля) — логин-коллекцию
# gnome-keyring не создаёт. Пароль коллекции — из ~/.config/max/keyring-pass
# (0600), при первом запуске генерируется. Пустой мастер-пароль gnome-keyring
# для login-коллекции не принимает (проверено) — пароль обязателен.
# ВАЖНО: org.freedesktop.secrets на шине обязан держать НАШ демон — systemd-
# D-Bus-активация (gnome-keyring-daemon.socket) при обращении MAX к секретам
# поднимает свой юнит с ПУСТЫМ паролем, которому наша коллекция недоступна
# ("object does not exist"). Поэтому при необходимости перехватываем шину:
# стоп активатора, снятие чужих демонов, подъём своего (--login + --start).
KP="${XDG_CONFIG_HOME:-$HOME/.config}/max/keyring-pass"
if command -v gdbus >/dev/null 2>&1; then
	RU="/run/user/$(id -u)"
	if [ ! -s "$KP" ]; then
		mkdir -p "${KP%/*}" 2>/dev/null
		umask 077
		head -c 24 /dev/urandom | base64 | tr -d '\n' > "$KP" 2>/dev/null
		chmod 600 "$KP" 2>/dev/null
	fi
	if [ -s "$KP" ]; then
		LOCKED=true
		DBUS_SESSION_BUS_ADDRESS="unix:path=$RU/bus" gdbus call --session \
			--dest org.freedesktop.secrets --object-path /org/freedesktop/secrets/collection/login \
			--method org.freedesktop.DBus.Properties.Get \
			org.freedesktop.Secret.Collection Locked 2>/dev/null | grep -q false && LOCKED=false
		if [ "$LOCKED" = true ]; then
			systemctl --user stop gnome-keyring-daemon.socket 2>/dev/null || true
			for _p in $(ps -eo pid,args | awk '$2 == "/usr/bin/gnome-keyring-daemon" {print $1}'); do
				kill -9 "$_p" 2>/dev/null || true
			done
			sleep 1
			printf '%s\n' "$(cat "$KP")" | /usr/bin/gnome-keyring-daemon --login \
				--components=secrets,ssh,pkcs11 >/dev/null 2>&1 || true
			/usr/bin/gnome-keyring-daemon --start >/dev/null 2>&1 || true
			sleep 1
		fi
	fi
fi
# Запуск из каталога, который пересоздали под ногами (emerge --unmerge + emerge
# воссоздают /opt/max с ДРУГИМ инодом; отключённый носитель — то же самое).
# "[ -d $PWD ]" и bash'овский `pwd -P` этот случай НЕ ловят (путь существует).
# Надёжный признак — суффикс "(deleted)" у /proc/self/cwd; без ухода из такого
# cwd приложение абортит SIGABRT сразу после первой строки лога (воспроизведено).
case "$(readlink /proc/self/cwd 2>/dev/null)" in
	*'(deleted)') cd "$HOME" 2>/dev/null || cd / ;;
esac
# QT_QUICK_BACKEND=software сюда НЕ ставить: он нужен только при изолированном
# запуске (USE="jail-net", включает сам лаунчер), а на хосте рисует чёрную
# полосу ~70px внизу окна (замер: строки яркости 0.0 против равномерных 77.7
# при нативном GL).
# GRPC_DNS_RESOLVER=native (r19): gRPC в max по умолчанию резолвит адреса
# через c-ares, который ХОДИТ В DNS-серверы из /etc/resolv.conf
# (nameserver 127.0.0.1) и игнорирует /etc/hosts — на машине без локального
# DNS на 127.0.0.1:53 звонковый RPC-клиент падает с "DNS resolution failed
# for localhost ... Could not contact DNS servers" (CallsSDK getStatus).
# native резолвер использует системный getaddrinfo (nsswitch + /etc/hosts) —
# localhost резолвится из hosts, RPC-клиент соединяется с max-service.
export GRPC_DNS_RESOLVER=native
# EXDEV-фикс (r18): MAX скачивает медиа во временный каталог, затем делает
# rename() в ~/.local/share/ONEME/... При незаданном TMPDIR Qt-рантайм
# берёт /tmp (tmpfs, st_dev=37), а ONEME лежит на диске (st_dev=2181) —
# rename между ФС даёт "Invalid cross-device link" (видео не доскачивается,
# FsAccessor::tryMoveFile). Направляем TMPDIR в ~/.cache/ONEME/tmp — тот же
# диск, что данные, — нетронутым остаётся системный /tmp для всего остального.
XDG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
if [ ! -d "$XDG_CACHE/ONEME/tmp" ]; then
	mkdir -p "$XDG_CACHE/ONEME/tmp" 2>/dev/null || true
fi
export TMPDIR="$XDG_CACHE/ONEME/tmp"
# Служебные окна процесса max-service (WM_CLASS "max-service","Max-service" и
# "max-service","MAX", 10x10 и 2x2) помечены _XEMBED_INFO (притворяются
# трей-иконками), попадают в панель задач лишними плитками, а compiz+emerald
# вешают на них decoration с заголовком 30px — виден «кусочек» рамки. Гасим
# фоновым watcher'ом (подробности в /usr/libexec/max-winfix/max-winfix.sh):
# он снимает _XEMBED_INFO и ставит SKIP_TASKBAR/SKIP_PAGER. Признак — НЕ
# WM_CLASS (у главного окна первый компонент тот же), а имя процесса-владельца:
# comm=max-service. Одного SKIP_TASKBAR мало: пока висит _XEMBED_INFO, панель
# показывает окно как трей-иконку (проверено). Тип окна роли не играет:
# снятия _XEMBED_INFO достаточно (проверено на живом окне с NORMAL).
# Watcher получает PID ещё НЕ exec'нутой оболочки: после exec PID сохраняется
# (exec заменяет образ процесса), поэтому kill -0 в watcher'е отслеживает
# именно основной max. Запускаем только в графической сессии.
if [ -x /usr/libexec/max-winfix/max-winfix.sh ] && [ -n "$DISPLAY" ]; then
	/usr/libexec/max-winfix/max-winfix.sh "$$" >/dev/null 2>&1 &
fi
exec /opt/max/bin/max "$@"
BASE
	} > "${D}/usr/bin/max" || die
	fperms 0755 /usr/bin/max

	# .desktop: Exec -> наша обёртка (в deb жёстко прописан /usr/share/max/bin/max);
	# DBusActivatable=true без dbus-сервиса в пакете — выпиливаем (QA-валидация)
	insinto /usr/share/applications
	sed -e 's#^Exec=.*#Exec=/usr/bin/max %U#' -e '/^DBusActivatable=/d' \
		"${S}/usr/share/applications/max.desktop" \
		> "${D}/usr/share/applications/max.desktop" || die
	insinto /usr/share/pixmaps
	doins "${S}/usr/share/pixmaps/max.png"

	local size
	for size in 16 24 32 48 64 128 256 512; do
		insinto "/usr/share/icons/hicolor/${size}x${size}/apps"
		doins "${S}/usr/share/icons/hicolor/${size}x${size}/apps/max.png"
	done

	# Watcher служебного окна max-service: убирает вторую плитку из панели
	# задач и decoration Emerald вокруг окна-пустышки 10x10 (см. обёртку выше).
	exeinto /usr/libexec/max-winfix
	doexe "${FILESDIR}/max-winfix.sh"

	if use jail-net; then
		# лаунчер джейла + маркер включения
		exeinto /usr/libexec/max-jail
		doexe "${FILESDIR}/max_jail.sh"
		insinto /usr/libexec/max-jail
		doins "${FILESDIR}/README.jail.md"
		keepdir /etc/max
		touch "${D}/etc/max/jail-net" || die
	fi

	if use qt_stack_build; then
		# собранные Qt-либы поверх вендорских (build-дерево из src_compile);
		# откат: emerge -1 без флага — deb отдаст вендорские снова
		qt_deploy_stack
	fi
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update

	# USE=qt_stack_build: Qt собран in-tree в src_compile и подложен в
	# src_install — отдельная команда после emerge НЕ нужна (r16).
	if use qt_stack_build; then
		elog "USE=qt_stack_build: Qt 6.11.0 собран из исходников (qtbase+qtsvg,"
		elog "прямой cmake/ninja в src_compile) и подложен в /opt/max/lib64."
		elog "Откат на вендорские libQt6: emerge -1 net-im/max (без флага)."
	else
		elog "В /opt/max/lib64 — вендорские Qt-либы из .deb. Версия с собранными"
		elog "из исходников: USE='qt_stack_build' emerge -1 net-im/max (~8 мин)."
	fi
	elog "Амнезия входа исправлена: ключ SQLCipher-БД сохраняется в keyring-коллекции"
	elog "login (пароль из ~/.config/max/keyring-pass, 0600, создаётся при первом"
	elog "запуске; обёртка разблокирует коллекцию автоматически, если нужно)."

	if use jail-net; then
		elog "Изолированный запуск включён (/usr/bin/max -> max_jail.sh)."
		elog "Запуск требует passwordless sudo; добавь в sudoers:"
		elog "  %wheel ALL=(root) NOPASSWD: /usr/libexec/max-jail/max_jail.sh"
		elog "Данные приложения: ~/.config/ONEME, ~/.local/share/ONEME, ~/.cache/ONEME."
		elog "Вернуться к обычному запуску: emerge -1 net-im/max (без jail-net)."
	else
		elog "Обычный запуск: /usr/bin/max (или пункт меню MAX)."
		elog "Изоляция при желании: USE='jail-net' emerge -1 net-im/max."
	fi

	# Провайдер Secret Service: приложение (бандловая libsecret) хранит ключ
	# своей SQLCipher-базы в коллекции "login". Без живого сервиса база
	# считается битой и удаляется на каждом запуске ("Database key is
	# incorrect, remove database" -> повторный QR-вход).
	if ! has_version gnome-base/gnome-keyring && ! has_version kde-frameworks/kwallet; then
		ewarn "Нет провайдера Secret Service (gnome-base/gnome-keyring): вход будет сбрасываться."
	fi
	# Портал-бэкенд: без него org.freedesktop.portal.Settings/FileChooser
	# отсутствуют -> тема не читается, диалоги выбора файлов не работают
	# (в логе соответствующие Warning). Для MATE/GTK подходит -gtk.
	if ! has_version sys-apps/xdg-desktop-portal-gtk \
		&& ! has_version sys-apps/xdg-desktop-portal-kde \
		&& ! has_version sys-apps/xdg-desktop-portal-wlr; then
		elog "Совет: поставь sys-apps/xdg-desktop-portal-gtk — тогда заработают тема (Settings),"
		elog "диалоги выбора файлов (FileChooser) и нотификации через портал."
	fi
	elog "Известные ограничения нативной сборки (не лечатся из пакета):"
	elog "  * трей — QtQuick.Labs.Platform требует QApplication, а клиент QGuiApplication;"
	elog "    в бандловом xcb-плагине нет ни StatusNotifier, ни XEmbed (см. max-internals.md §4);"
	elog "  * max-service (313 МБ в /opt/max/bin) поднимается, но его собственный"
	elog "    бандловый стек вычищен (r19) — звонки работают через системные либы."
	elog "Служебные окна процесса max-service (лишние плитки в панели задач и"
	elog "decoration-«кусочек» вокруг окна 10x10) гасит фоновый watcher (r23):"
	elog "снимает _XEMBED_INFO и ставит SKIP_TASKBAR/SKIP_PAGER. DOCK не нужен"
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}