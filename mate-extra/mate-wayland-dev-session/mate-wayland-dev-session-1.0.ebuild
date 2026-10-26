EAPI=8

DESCRIPTION="MATE Wayland-сессия из приватной сборки (dev-префикс ~/mate-dev) + сборщик в этот префикс"
HOMEPAGE="https://github.com/KosmiK2001/kosmik2001-overlay"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64"

# Исходников нет — всё из FILESDIR.
S="${WORKDIR}"

# Нужна системная Wayland-сессия (wayfire + startmatewayland из
# mate-session-manager с PR #340) — dev-сессия только подменяет окружение.
RDEPEND="
	gui-wm/wayfire
	>=mate-base/mate-session-manager-1.28
	app-misc/rsync
"

src_install() {
	dobin "${FILESDIR}"/start-mate-wayland-dev
	dobin "${FILESDIR}"/mate-dev-build

	insinto /usr/share/wayland-sessions
	doins "${FILESDIR}"/mate-wayland-dev.desktop
}
