# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Live-версия (9999): метапакет, собственного исходника нет — только зависимости, все пины смотрят на 9999.
# Зависимости, USE-флаги, аргументы configure и фазы совпадают с релизным
# ebuildом ::gentoo 1.28.0, чтобы сборка из исходников не отличалась от
# «натуральной». Установка и dev-цикл (форк, своя ветка, локальный клон) —
# README оверлея, секция «MATE live (9999)».

EAPI=8

MATE_BRANCH="$(ver_cut 1-2)"

DESCRIPTION="Meta package for MATE panel applets"
HOMEPAGE="https://wiki.gentoo.org/wiki/No_homepage"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="**"
IUSE="appindicator networkmanager sensors"

RDEPEND="=mate-base/mate-applets-${MATE_BRANCH}*
	appindicator? ( =mate-extra/mate-indicator-applet-${MATE_BRANCH}* )
	networkmanager? ( gnome-extra/nm-applet )
	sensors? ( =mate-extra/mate-sensors-applet-${MATE_BRANCH}* )
"
