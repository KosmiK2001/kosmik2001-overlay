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

# Флаги отладки выключены по умолчанию осознанно: обычному
# пользователю они не нужны, пакет работает и без них. Включать их будут
# те, кто сознательно разбирается.
#
#   debug     XS_ENABLE_CRASH_LATCHER - ловец SIGSEGV с backtrace.
#             Нужен потому, что ядро собрано без CONFIG_ELF_CORE, и
#             coredump невозможен физически, а gdb на живом демоне не
#             ловит гонки: под gdb они не проявляются. Без этого флага
#             узнать, где упал демон, нечем.
#   memdebug  XS_MEM_DEBUG - SIGUSR1 -> malloc_trim(0) и периодический
#             лог RSS/mallinfo2. Полезно при подозрении на рост памяти.
#   sanitize  ASan + UBSan, обязательно с -O0 -g3, иначе отчёты
#             бесполезны. Ловит гонки, use-after-free, выходы за границы.
#
# Любой из них отключает upx - см. проверку в src_install.
IUSE="+upx debug memdebug sanitize"

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
	sys-devel/gettext
	"

# upx нужен только когда демон реально упаковывается, то есть при
# USE=upx и БЕЗ отладочных флагов. Раньше стояло просто
# "upx? ( app-arch/upx )", и этого мало: при USE="debug" флаг upx
# остаётся включённым (+upx -debug), поэтому upx тянулся даже там, где
# src_install его не использует.
# "!debug? ( )" в RDEPEND проблему не решает: это ЗАПРЕТ пакета при
# USE=debug, который складывается с требованием выше в конфликт
# резолва при USE="debug upx".
#
# Правильная форма - единственное условие сразу на обоих флагах.
# Проверено на --emptytree: без debug upx тянется, с любым из debug,
# memdebug, sanitize - не тянутся.
RDEPEND="${DEPEND} upx? ( !debug? ( !memdebug? ( !sanitize? ( app-arch/upx ) ) ) )"

# Категория upx - именно app-arch: в дереве gentoo есть только
# app-arch/upx, каталога sys-apps/upx не существует, и emerge на
# sys-apps/upx отвечает "there are no ebuilds to satisfy".

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

	# Флаги отладки -> макросы компилятора. Пустая строка по умолчанию,
	# обычная сборка не меняется.
	#
	# xs_debug_cflags уходит в EXTRA_CFLAGS, а не в CFLAGS: в Makefile
	# CFLAGS = ... жёстким присваиванием, и внешний CFLAGS затирается.
	local xs_debug_cflags=""
	use debug    && xs_debug_cflags+=" -DXS_ENABLE_CRASH_LATCHER"
	use memdebug && xs_debug_cflags+=" -DXS_MEM_DEBUG"

	if use sanitize; then
		# ASan/UBSan требуют -O0 -g3. Без них отчёты бесполезны: оптимизатор
		# выкидывает нужные стек-кадры, и ASan указывает на несуществующее
		# место. CFLAGS здесь переопределяем целиком, а не дописываем.
		xs_debug_cflags+=" -DXS_ENABLE_CRASH_LATCHER -DXS_MEM_DEBUG"
		xs_debug_cflags+=" -fsanitize=address -fsanitize=undefined"
		xs_debug_cflags+=" -fno-omit-frame-pointer -fno-optimize-sibling-calls"
		xs_debug_cflags+=" -fno-common -g3 -O0"
		# ASan перехватывает malloc; conlog держит 200 строк и под санитайзером
		# это заметно медленнее - снижаем частоту опроса логов, иначе демон
		# сам станет источником проблем.
		export XSCREENLETS_MEM_POLL="${XSCREENLETS_MEM_POLL:-300}"
	fi

	if [[ -n "${xs_debug_cflags}" ]]; then
		elog "Отладочная сборка:${xs_debug_cflags}"
	fi

	emake EXTRA_CFLAGS="${CFLAGS} ${CPPFLAGS} -DXS_PLUGIN_DIR=\\\"${plugin_dir}\\\" -DXS_THEME_DIR=\\\"${theme_dir}\\\"${xs_debug_cflags}" \
		|| die "build failed"

	# conlog_min НЕ входит в цель all (в отличие от полного conlog, см.
	# верх файла), поэтому собирается отдельным вызовом make. Без этого
	# build/conlog_min.so не появится, и проверка ниже уронит установку.
	emake build/conlog_min.so \
		EXTRA_CFLAGS="${CFLAGS} ${CPPFLAGS} -DXS_PLUGIN_DIR=\\\"${plugin_dir}\\\" -DXS_THEME_DIR=\\\"${theme_dir}\\\"${xs_debug_cflags}" \
		|| die "conlog_min build failed"

	# Каталог переводов. Отдельный от ${EROOT}/usr/share/locale по
	# умолчанию Gentoo: пакет ставит .mo через цикл ниже, и путь
	# должен совпадать с тем, что зашит в демон через XS_LOCALEDIR.
	localedir="${EROOT}/usr/share/locale"

	# Проверка: пути должны быть реально зашиты, иначе демон будет искать
	# плагины и темы в $HOME и пакет окажется нерабочим. Раньше такая
	# проверка отсутствовала, и это молча ломало установку.
	grep -q "${plugin_dir}" build/xscreenletsd \
		|| die "XS_PLUGIN_DIR did not get compiled in (${plugin_dir} not in daemon)"
	grep -q "${theme_dir}" build/xscreenletsd \
		|| die "XS_THEME_DIR did not get compiled in (${theme_dir} not in daemon)"
	grep -q "${localedir}" build/xscreenletsd \
		|| die "XS_LOCALEDIR did not get compiled in (${localedir} not in daemon)"
	# Без этого демон запускается, но gettext ищет переводы не там, и
	# интерфейс молча остаётся английским. Проверка ловит именно это:
	# сборка успешна, ошибок нет, перевода нет.

	# Переводы. msgfmt берётся из sys-devel/gettext, добавленного в
	# DEPEND. Каталог .mo задаётся через LOCALEDIR: он попадает в
	# Makefile как -DXS_LOCALEDIR, и демон ищет переводы именно там.
	# Без этой цели демон соберётся, но интерфейс останется
	# английским - поэтому она обязательна, а не опциональна.
	make locale LOCALEDIR="${localedir}" \
		|| die "locale build failed"
}

# Установка делается вручную, а не через make install: в Makefile
# PREFIX по умолчанию $(HOME), и его install-цель кладёт плагины в
# $(PREFIX)/lib/xscreenlets/plugins, тогда как нам нужно libexec.
src_install() {
	local d p

	# Пакет собирается ради GTK+-приложений; демон - главный бинарник.
	#
	# UPX применяется ЗДЕСЬ, до dobin, а не в pkg_postinst. Причина в
	# порядке фаз portage: merge -> postinst -> AUTOCLEAN-unmerge. Упаковка
	# в postinst бессмысленна: CONTENTS хранит md5 неупакованного файла,
	# после упаковки md5 меняется, и AUTOCLEAN считает файл посторонним и
	# удаляет его, после чего merge пишет свежую неупакованную копию.
	# Именно так это и выглядело на живой установке: postinst отработал и
	# сообщил "Демон упакован UPX: 121136 -> 42876", а на диске лежал
	# неупакованный файл с md5, совпадающим с CONTENTS.
	#
	# Упаковка до merge даёт верный CONTENTS: md5 в базе соответствует
	# упакованному бинарнику, и AUTOCLEAN его не трогает. Так же сделано
	# в x11-misc/fusion-icon2 из этого же оверлея - проверено: там
	# /usr/bin/fusion-icon2 упакован, и его md5 совпадает с CONTENTS.
	#
	# Порядок важен: сначала strip (вручную, т.к. FEATURES=strip в этой
	# системе не задан), затем upx. Обратный порядок бессмысленен - strip
	# не сможет распаковать, а upx и так пакует уже очищенный бинарник.
	#
	# Отладочная сборка и UPX несовместимы: upx сжимает машинный код, и
	# backtrace из ловца падений, и отчёты ASan указывают на адреса внутри
	# упакованного образа, а не на исходный код. Молча упакованный отладочный
	# бинарник бесполезен - поэтому молча НЕ упаковываем, а пишем в elog.
	local xs_debug_on=0
	use debug    && xs_debug_on=1
	use memdebug && xs_debug_on=1
	use sanitize && xs_debug_on=1

	if [[ ${xs_debug_on} -ne 0 ]]; then
		# strip -s здесь НЕ делаем, в отличие от обычной ветки ниже.
		# Он вырезает DWARF, а без него бесполезны:
		#   - heaptrack: перехват malloc идёт через LD_PRELOAD и работает,
		#     но имена функций в стеке берутся из DWARF - будут адреса
		#     вместо xs_core_*;
		#   - backtrace ловца падений: тот же DWARF;
		#   - отчёты ASan/UBSan: символизация требует символов.
		# -g3 и так приходит из CFLAGS при USE=sanitize.
		elog "Отладочная сборка: UPX пропущен (упаковка ломает backtrace и отчёты санитайзера)."
	elif use upx; then
		if command -v upx >/dev/null 2>&1; then
			strip -s build/xscreenletsd 2>/dev/null
			if upx -9 --ultra-brute build/xscreenletsd >/dev/null 2>&1; then
				elog "Демон упакован UPX: $(stat -c %s build/xscreenletsd) байт"
			else
				ewarn "UPX не смог упаковать демон, будет поставлен как есть."
			fi
		else
			ewarn "USE=\"+upx\", но upx не найден - демон оставлен как есть."
		fi
	else
		elog "USE=\"-upx\": демон без упаковки."
	fi
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
	# Список из 12 в цикле + conlog_min отдельно = 13. acpi_battery в
	# этот список добавлен 14-м: у него есть собственный core
	# (acpi_battery_core.c), который тоже собирается, - без отдельной
	# проверки отсутствие core.o даст невнятную ошибку линковки.
	for p in clock calendar launcher frame_launcher clearrss clearweather \
	         cpu_monitor memory_monitor disk_monitor network_monitor \
	         sensors process_list acpi_battery; do
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
	# Ставим ВСЕ иконки из icons/, а не захардкоженный список: перечень
	# типов апплетов расширялся, и applet_manager показывал для новых
	# типов иконку-заглушку application-x-executable.
	for f in icons/*.svg; do
		[[ -f ${f} ]] && doins "${f}"
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

	# Переводы: build/locale/<язык>/LC_MESSAGES/xscreenlets.mo,
	# собранные целью locale выше. Ставим циклом по языкам, а не
	# одним doins - иначе в /usr/share/locale попал бы лишний уровень
	# build/locale, и gettext каталог не нашёл бы.
	#
	# Каталог задаётся явно ${EROOT}/usr/share/locale, тем же, что
	# зашит в демон через XS_LOCALEDIR (см. src_compile). Русский и
	# остальные языки - по одному файлу каждый.
	local mo lang
	for lang in "${S}/po/"*.po; do
		[[ -f ${lang} ]] || continue
		lang=$(basename "${lang}" .po)
		mo="build/locale/${lang}/LC_MESSAGES/xscreenlets.mo"
		[[ -f ${mo} ]] || die "missing translation: ${mo}"
		insinto "/usr/share/locale/${lang}/LC_MESSAGES"
		doins "${mo}"
	done

	# Список переводов в сообщение emerge: пользователь должен видеть,
	# какие языки реально установлены, иначе непонятно, почему
	# интерфейс не переводится.
	elog "Установлены переводы:"
	for lang in "${S}/po/"*.po; do
		[[ -f ${lang} ]] || continue
		elog "  $(basename "${lang}" .po)"
	done
}

pkg_postinst() {
	# Упаковки демона здесь нет намеренно: см. длинный комментарий в
	# src_install. Упаковка в postinst откатывается AUTOCLEAN-unmerge,
	# потому что CONTENTS хранит md5 неупакованного файла.

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
