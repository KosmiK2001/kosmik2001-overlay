EAPI=8

DESCRIPTION="Чистая Wayland-сессия MATE: labwc как композитор, компоненты MATE — нативные Wayland-клиенты"
HOMEPAGE="https://github.com/KosmiK2001/kosmik2001-overlay"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64"

# Исходников нет — всё ставится из FILESDIR, поэтому S должен существовать.
S="${WORKDIR}"

# Сессия имеет смысл только с wayland-собранными компонентами: панель должна
# уметь layer-shell (gtk-layer-shell + libxfce4windowing для window-list),
# а демон уведомлений — свой wayland-бэкенд.
RDEPEND="
	gui-wm/labwc
	>=mate-base/mate-panel-1.28[wayland]
	>=mate-base/mate-applets-1.28[in-process]
	>=mate-base/caja-1.28[wayland]
	>=mate-base/mate-settings-daemon-1.28[wayland]
	>=mate-extra/mate-media-1.28[wayland]
	>=mate-extra/mate-utils-1.28[wayland]
	>=mate-extra/mate-sensors-applet-1.28[in-process]
	>=x11-misc/mate-notification-daemon-1.28[wayland]
	mate-extra/mate-polkit
	mate-base/mate-session-manager
"

src_install() {
	dobin "${FILESDIR}"/mate-wayland-session
	dobin "${FILESDIR}"/mate-wayland-wm-stub

	insinto /usr/share/wayland-sessions
	doins "${FILESDIR}"/mate-wayland.desktop

	insinto /usr/share/mate-wayland/labwc
	doins "${FILESDIR}"/autostart
	fperms 0755 /usr/share/mate-wayland/labwc/autostart
}
