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
# Нужен только на этапе установки: postinst пакует демона, и после этого
# upx больше нигде не требуется. Категория именно app-arch, а не sys-apps:
# в дереве gentoo есть только app-arch/upx, и emerge на sys-apps/upx
# отвечает "there are no ebuilds to satisfy".
RDEPEND+=" app-arch/upx"

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

# EPREFIX здесь пуст (ROOT=/), поэтому ${EPREFIX}/... дало бы /libexec
# вместо /usr/libexec. Пути жёстко /usr: профиль merged-usr, usrmerge
# делает /bin симлинком на usr/bin, из-за чего демон случайно оказывался
# в правильном месте, а плагины и темы - нет.
PLUGIN_DIR="/usr/libexec/xscreenlets"
THEME_DIR="/usr/share/xscreenlets"

src_compile() {
	# Пути, зашиваемые в демон. Пакет ставится в /usr, а EPREFIX здесь
	# пуст (ROOT=/), поэтому ${EPREFIX}/libexec дало бы /libexec - мимо
	# /usr. Значения идут в EXTRA_CFLAGS, а не в append-cflags/CFLAGS:
	# в Makefile CFLAGS = ... жёстким присваиванием, и переданный извне
	# CFLAGS затирается. EXTRA_CFLAGS дописывается в конец и перекрывает
	# базовые -O2/-g3, что и нужно.
	local plugin_dir="/usr/libexec/xscreenlets"
	local theme_dir="/usr/share/xscreenlets"

	emake EXTRA_CFLAGS="${CFLAGS} ${CPPFLAGS} -DXS_PLUGIN_DIR=\\\"${plugin_dir}\\\" -DXS_THEME_DIR=\\\"${theme_dir}\\\"" \
		|| die "build failed"

	# conlog_min НЕ входит в цель all (в отличие от полного conlog, см.
	# верх файла), поэтому собирается отдельным вызовом make. Без этого
	# build/conlog_min.so не появится, и проверка ниже уронит установку.
	emake build/conlog_min.so \
		EXTRA_CFLAGS="${CFLAGS} ${CPPFLAGS} -DXS_PLUGIN_DIR=\\\"${plugin_dir}\\\" -DXS_THEME_DIR=\\\"${theme_dir}\\\"" \
		|| die "conlog_min build failed"

	# Проверка: пути должны быть реально зашиты, иначе демон будет искать
	# плагины и темы в $HOME и пакет окажется нерабочим. Раньше такая
	# проверка отсутствовала, и это молча ломало установку.
	grep -q "${plugin_dir}" build/xscreenletsd \
		|| die "XS_PLUGIN_DIR did not get compiled in (${plugin_dir} not in daemon)"
	grep -q "${theme_dir}" build/xscreenletsd \
		|| die "XS_THEME_DIR did not get compiled in (${theme_dir} not in daemon)"
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

	# Права отдельно не выставляем: newexe и сам ставит 0755 на все
	# установленные .so (проверено на реальной сборке - все 13 файлов
	# получили 755). Прежняя попытка сделать это через fperms ломала
	# установку: fperms сам префиксует ${ED}, и путь "${ED}/${PLUGIN_DIR}"
	# давал вдвое - image/.../image//libexec/..., после чего chmod не
	# находил файлов и install-фаза падала.

	# Иконки апплетов (для списка/настроек).
	# Именно insinto, а не только dodir: dodir лишь создаёт каталог, и
	# последующий doins ушёл бы в корень пакета. Так и вышло - пять
	# иконок оказались в /clearrss.svg вместо
	# /usr/share/icons/xscreenlets/.
	dodir "/usr/share/icons/xscreenlets"
	insinto "/usr/share/icons/xscreenlets"
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
	# Упаковка демона: 121136 -> 42876 байт (-64%).
	#
	# Только демон. UPX 4.x принципиально не умеет упаковывать ELF shared
	# objects: на всех 13 плагинах он отказывается с
	#   CantPackException: PT_NOTE above stub
	# Это ограничение самого UPX, а не нашей сборки - тот же отказ дают
	# посторонние системные libexpat.so.1 и libbz2.so.1.0. Обойти нельзя:
	# -f, --no-reloc, --all-modules, --ultra-brute и удаление
	# .note.gnu.build-id через objcopy дают тот же отказ.
	#
	# strip -s не делаем: portage уже стрипует при установке, проверено -
	# повторный strip не меняет ни байта.
	#
	# Отказ упаковки НЕ должен ломать установку: демон и без UPX работоспособен,
	# поэтому молча продолжаем.
	if command -v upx >/dev/null 2>&1; then
		local d="${EROOT}${ED}/usr/bin/xscreenletsd"
		local before after
		before=$(stat -c %s "${d}" 2>/dev/null)
		if [[ -z "${before}" ]]; then
			ewarn "Демон не найден по пути ${d}, упаковка пропущена."
		elif upx -9 --ultra-brute "${d}" >/dev/null 2>&1; then
			after=$(stat -c %s "${d}" 2>/dev/null)
			elog "Демон упакован UPX: ${before} -> ${after} байт"
		elif upx -t "${d}" >/dev/null 2>&1; then
			# AlreadyPackedException на повторном postinst (emerge --regen и
			# т.п.) - это не ошибка, файл уже упакован.
			elog "Демон уже упакован UPX (${before} байт)."
		else
			ewarn "UPX не смог упаковать демон, оставлен как есть."
		fi
	fi

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
