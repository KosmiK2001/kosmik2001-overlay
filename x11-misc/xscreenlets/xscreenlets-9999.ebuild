# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="C/GTK3 rewrite of screenlets: desktop applets on the X root window"
HOMEPAGE="https://github.com/KosmiK2001/xscreenlets"
EGIT_REPO_URI="https://github.com/KosmiK2001/xscreenlets.git"
EGIT_BRANCH="main"

LICENSE="MIT"
SLOT="0"
KEYWORDS="**"

# conlog ставится урезанной версией (conlog_min). Полный парсер на
# больших логах брал ~90% CPU и ~290000 строк/с, из-за чего демон
# становился неубиваемым; сведения в src/widgets/CONLOG-FUNCTIONALITY.md
# в исходниках.
# Проверено ldd по всем 13 плагинам:
#   librsvg, gdk-pixbuf, libxml2, X11 - нужны всем;
#   net-libs/libsoup:3.0 - clearrss и clearweather (разбор RSS/погоды);
#   dev-libs/json-glib - только clearweather.
#
# Категории указаны по фактическим каталогам дерева gentoo: gtk+ лежит
# в x11-libs, gdk-pixbuf тоже (а не в dev-libs, как можно ошибиться по
# pkg-config). dev-libs/gmodule отдельного пакета НЕ существует -
# gmodule собирается внутри dev-libs/glib, поэтому отдельной строкой он
# не указывается. У libsoup ветви различаются слотом, а не сокетом:
# pkg-config libsoup-3.0 соответствует SLOT="3.0" (у ветки 2.74
# SLOT="2.4"), поэтому сокет именно 3.0. У json-glib слот 0, а не 1.
DEPEND="
	>=dev-libs/glib-2.66:2
	x11-libs/gtk+:3
	gnome-base/librsvg:2
	x11-libs/gdk-pixbuf:2
	dev-libs/libxml2:2
	net-libs/libsoup:3.0
	dev-libs/json-glib:0
	x11-libs/libX11
	x11-libs/libXext
	"
RDEPEND="${DEPEND}"

# Плагины грузятся демоном через dlopen(), поэтому их не видно
# portage'овскому scanner'у зависимостей. Содержимое src/core/applet_manager.c
# содержит dlopen() со строковым аргументом, но не литерал ".so" вплотную
# к нему, и без USE="module" ebuild считается битым.
RESTRICT="test"

DOCS=( README.md CONFIG_SCHEME.md )

# ---------------------------------------------------------------------------
# Пути. Задаются на этапе компиляции через -D, а не вписываются в
# исходники, поэтому один и тот же tarball годится и для /usr, и для
# другого префикса.
#
# Демон ищет плагины сначала в каталоге пользователя
# (~/lib/xscreenlets/plugins), затем в XS_PLUGIN_DIR, а темы - в
# $XDG_CONFIG_HOME/xscreenlets/themes, затем в ~/.xscreenlets/themes и
# только потом в XS_THEME_DIR. Пользовательские ресурсы имеют приоритет
# над пакетными, поэтому настройка не перекрывается установкой.
# ---------------------------------------------------------------------------

PLUGIN_DIR="${EPREFIX}/libexec/xscreenlets"
THEME_DIR="${EPREFIX}/share/xscreenlets"

src_compile() {
	local plugin_dir="${PLUGIN_DIR}" theme_dir="${THEME_DIR}"

	append-cflags \
		-DXS_PLUGIN_DIR="\"${plugin_dir}\"" \
		-DXS_THEME_DIR="\"${theme_dir}\""

	# В Makefile EXTRA_CFLAGS, а не CPPFLAGS: этот же список попадает
	# в строки линковки плагинов, и -D в них не нужен.
	emake EXTRA_CFLAGS="${CFLAGS} ${CPPFLAGS}" || die "build failed"

	# conlog_min НЕ входит в цель all (в отличие от полного conlog, см.
	# верх файла), поэтому собирается отдельным вызовом make. Без этого
	# build/conlog_min.so не появится, и проверка ниже уронит установку.
	emake build/conlog_min.so EXTRA_CFLAGS="${CFLAGS} ${CPPFLAGS}" \
		|| die "conlog_min build failed"
}

# Установка делается вручную, а не через make install: в Makefile
# PREFIX по умолчанию $(HOME), и его install-цель кладёт плагины в
# $(PREFIX)/lib/xscreenlets/plugins, тогда как нам нужно libexec.
src_install() {
	local d p

	# Пакет собирается ради GTK+-приложений; демон - главный бинарник.
	dobin build/xscreenletsd

	# build/xclock - отдельная standalone-версия часов, собирается
	# как побочный продукт и в поставку не входит: ему нужен свой
	# набор тем, и пользователю он не нужен при установленном пакете.
	rm -f build/xclock

	# 12 плагинов из цели all. Имена соответствуют TARGET_*_PLUGIN.
	# conlog в all не входит, его ставим отдельно, итого 13.
	#
	# newexe принимает РОВНО два аргумента (newexe <src> <dest>) - параметра
	# -m у него нет, и передача третьего аргумента валит установку с
	# "newexe: -m does not exist". Права задаются через fperms отдельно.
	dodir "${PLUGIN_DIR}"
	for p in clock calendar launcher frame_launcher clearrss clearweather \
	         cpu_monitor memory_monitor disk_monitor network_monitor \
	         sensors process_list; do
		[[ -f build/${p}.so ]] || die "missing plugin: ${p}.so"
		exeinto "${PLUGIN_DIR}"
		newexe "build/${p}.so" "${p}.so"
	done

	# conlog_min ставится под именем conlog.so. Полная версия
	# (build/conlog.so) в all не входит, и если она почему-то
	# собралась, её игнорируем: см. описание вверху файла.
	[[ -f build/conlog_min.so ]] || die "missing conlog_min.so"
	exeinto "${PLUGIN_DIR}"
	newexe build/conlog_min.so conlog.so

	# Плагины грузятся через dlopen(), поэтому им нужен исполняемый бит.
	fperms 0755 "${ED}/${PLUGIN_DIR}"/*.so

	# Иконки апплетов (для списка/настроек).
	dodir "${EPREFIX}/share/icons/xscreenlets"
	for p in clearrss cpu_monitor memory_monitor disk_monitor process_list; do
		[[ -f icons/${p}.svg ]] && doins "icons/${p}.svg"
	done

	# Темы. Раскладка в исходниках неоднородна, и это уже стоило двух
	# потерянных тем:
	#
	#   themes/clearrss/<тема>/*.svg    - подкаталог темы
	#   themes/clearweather/*.png       - каталог апплета БЕЗ подкаталога
	#
	# Оба апплета ищут тему как themes/<апплет>/<тема> (cw_find_theme
	# в clearweather.c подставляет "clearweather/default"), поэтому
	# clearweather надо положить в themes/clearweather/default - иначе
	# цикл themes/*/*/ его пропускает молча, а погода остаётся без темы.
	#
	# Перечислять файлы списком нельзя: так терялись shadow_mid.svg,
	# shadow.svg и button_bg.svg, и апплет выходил без теней кнопок.
	local t base sub
	for t in themes/*/; do
		[[ -d ${t} ]] || continue
		base=$(basename "${t}")

		# themes/<апплет>/<тема>/ - обычный случай
		local d
		for d in "${t}"*/; do
			[[ -d ${d} ]] || continue
			sub="${THEME_DIR}/${base}/$(basename "${d}")"
			dodir "${sub}"
			insinto "${sub}"
			doins "${d}"*
		done

		# themes/<апплет>/*.png - тема лежит прямо в каталоге апплета
		if compgen -G "${t}*.png" >/dev/null; then
			sub="${THEME_DIR}/${base}/default"
			dodir "${sub}"
			insinto "${sub}"
			doins "${t}"*
		fi
	done
}

pkg_postinst() {
	elog "Создайте первый апплет:"
	elog "  xscreenletsd &"
	elog
	elog "Плагины:      ${PLUGIN_DIR}"
	elog "Системные темы: ${THEME_DIR}"
	elog
	elog "Пользовательские ресурсы имеют приоритет над пакетными:"
	elog "  плагины: ~/lib/xscreenlets/plugins"
	elog "  темы:    ~/.config/xscreenlets/themes/<апплет>/<тема>"
	elog
	if [[ -d /usr/share/screenlets ]]; then
		ewarn "В системе остались темы оригинальных screenlets (python2) в"
		ewarn "/usr/share/screenlets. Апплеты попробуют взять тему оттуда,"
		ewarn "если своей не найдут. Если это нежелательно, переименуйте"
		ewarn "каталог или задайте тему явно."
	fi
}
