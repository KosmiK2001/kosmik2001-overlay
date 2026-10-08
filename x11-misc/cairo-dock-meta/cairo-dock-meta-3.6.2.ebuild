# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Meta ebuild for Cairo-Dock: the dock (core) plus its official plugins"
HOMEPAGE="https://github.com/Cairo-Dock/cairo-dock-core"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64 ~x86"

# Цикл избегается именно так: мета-пакет ничего не собирает и не требует на
# этапе сборки, поэтому обе половины можно свободно объявить в RDEPEND.
# Объявить эту же связку на самом core нельзя — плагины buildtime-зависимы от
# core (линкуются с libgldi), и emerge увидит цикл.
RDEPEND="
	x11-misc/cairo-dock
	x11-plugins/cairo-dock-plugins
"

# Мета-пакет не устанавливает файлов.
S="${WORKDIR}"

src_install() { :; }
