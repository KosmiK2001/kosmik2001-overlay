# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): git master upstream, github.com/infirit/caja-admin.
# В ::gentoo-ebuild'е ветка PV==9999 уже предусмотрена (git-r3 на тот же
# адрес), но PYTHON_COMPAT там 3.11..3.13 — на системе с единственным
# PYTHON_SINGLE_TARGET=python3_14 она не устанавливается. Здесь диапазон
# расширен до 3.14; всё остальное (meson, зависимости, фазы) без изменений.
#
# Требуется dev-python/python-caja с тем же расширением (лежит в этом оверлее).

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
