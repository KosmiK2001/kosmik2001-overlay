# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, mate-desktop/mate-common.
# Зависимости, USE-флаги и фазы совпадают с релизным ebuildом ::gentoo 1.28.0;
# единственное отличие продиктовано самим git-деревом — см. src_prepare ниже.
#
# Установка и dev-цикл (форк, своя ветка, локальный клон) — README оверлея,
# секция «MATE live (9999)».
#
# ВАЖНО: mate-common — фундамент всей live-сборки MATE. Именно он ставит
# /usr/bin/mate-doc-common, /usr/bin/mate-autogen и m4-макросы в aclocal, без
# которых mate.eclass на фазе prepare падает с
#     mate-doc-common: command not found
# (ematedocize вызывается принудительно: для PV=9999 eclass включает
# MATE_FORCE_AUTORECONF). Поэтому mate-common-9999 собирается ПЕРВЫМ.

EAPI=8

inherit autotools mate-desktop.org

DESCRIPTION="Common files for development of MATE packages"
LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="**"

src_prepare() {
	default

	# В релизном тарболсе configure и Makefile.in уже сгенерированы, в git-дереве
	# их нет. Без регенерации фазы молча ничего не делают: EAPI-8
	# default_src_configure вызывает econf только при наличии ./configure,
	# default_src_compile — при наличии Makefile. Пакет «собирается» успешно,
	# но ставит только документацию, и весь остальной live-набор MATE умирает
	# на отсутствии mate-doc-common (проверено на Q6600).
	# m4-макросы лежат в macros/, поэтому подсказываем aclocal каталог.
	AT_M4DIR="macros" eautoreconf
}

src_install() {
	mv doc-build/README README.doc-build \
		|| die "Failed to rename doc-build/README."

	default

	dodoc doc/usage.txt
}
