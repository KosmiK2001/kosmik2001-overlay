EAPI=8

inherit git-r3 gnome2-utils meson

DESCRIPTION="Официальная Wayland-сессия MATE: компоненты MATE внутри композитора Wayfire"
HOMEPAGE="https://github.com/mate-desktop/mate-wayland-session"
EGIT_REPO_URI="https://github.com/mate-desktop/mate-wayland-session.git"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="amd64"

# Upstream требует mate-settings-daemon >= 1.29.1: именно там появился wlrandr
# (display capplet + плагин msd), а также Wayland-бэкенды background и
# clipboard. На более старом msd его перезапуск в mate-wayland-components.sh
# уходит в бесконечный цикл, поэтому зависимость жёсткая и с флагом wayland.
#
# wf-background берётся из gui-apps/wf-shell: скрипт сессии добавляет
# `background = wf-background` в wayfire.ini.
RDEPEND="
	gui-wm/wayfire
	gui-apps/wf-shell
	>=mate-base/mate-settings-daemon-1.29.1[wayland]
	>=mate-base/mate-panel-1.28[wayland]
	>=mate-base/caja-1.28[wayland]
	mate-extra/mate-polkit
	>=x11-misc/mate-notification-daemon-1.28[wayland]
"
BDEPEND="
	sys-devel/gettext
"

PATCHES=(
	# Gentoo кладёт дефолтный конфиг в /usr/share/wayfire/wayfire.ini и не
	# ставит examples/. Без этого cp молча падает, и сессия стартует пустым
	# Wayfire без компонентов MATE.
	"${FILESDIR}"/${PN}-9999-gentoo-wayfire-ini-path.patch
)

pkg_postinst() {
	gnome2_schemas_update

	elog "Сессия «MATE (Wayland)» появится в меню любого DM (проверено с sddm)."
	elog "Композитор — Wayfire; конфиг сессии: ~/.config/mate/wayfire.ini."
	elog "Первая правка берётся из /usr/share/wayfire/wayfire.ini и дополняется"
	elog "автозапуском mate-wayland-components.sh."
	elog
	elog "Опционально для полной картины: gui-apps/wcm (настройка Wayfire),"
	elog "net-misc/network-manager-applet (nm-applet), net-wireless/blueman"
	elog "(blueman-applet) — скрипт сессии подхватывает их, если они есть."
}

pkg_postrm() {
	gnome2_schemas_update
}
