# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Теневая копия ebuild'а из ::gentoo (mate-extra/caja-admin-0.0.5) с одной
# правкой: PYTHON_COMPAT расширен до python3_14. На машине единственный
# PYTHON_SINGLE_TARGET=python3_14, поэтому апстримовый диапазон 3.11..3.13
# делал пакет неустанавливаемым (REQUIRED_USE не выполняется).
#
# Само расширение — один питоновский файл (extension/caja-admin.py.in), без
# привязки к версии Python в коде: только gi.repository + subprocess + gettext,
# и он парсится AST-проверкой на 3.14. Апстрим — github.com/infirit/caja-admin,
# НЕ mate-desktop, поэтому eclass mate здесь не используется (как и в дереве).
#
# Требует dev-python/python-caja с тем же расширением (лежит в этом оверлее).

EAPI=8

if [[ ${PV} == "9999" ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/infirit/caja-admin"
	KEYWORDS="**"
else
	SRC_URI="https://github.com/infirit/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

PYTHON_COMPAT=( python3_{11..14} )

inherit meson python-single-r1

DESCRIPTION="Caja Admin Extension"
HOMEPAGE="https://github.com/infirit/caja-admin"

LICENSE="GPL-3+"
SLOT="0"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

COMMON_DEPEND="${PYTHON_DEPS}"
RDEPEND="${COMMON_DEPEND}
	app-editors/pluma
	dev-python/python-caja[${PYTHON_SINGLE_USEDEP}]
	sys-auth/polkit
	x11-terms/mate-terminal
"
BDEPEND="${COMMON_DEPEND}
	sys-devel/gettext
"

src_install() {
	meson_src_install
	python_optimize "${D}/usr/share/caja-python/extensions"
}
