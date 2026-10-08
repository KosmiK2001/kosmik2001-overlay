# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Official plugins for Cairo-Dock: applets, rendering modes, indicators"
HOMEPAGE="https://github.com/Cairo-Dock/cairo-dock-plug-ins"
EGIT_REPO_URI="https://github.com/Cairo-Dock/cairo-dock-plug-ins.git"
EGIT_BRANCH="master"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="**"

# Плагины грузятся ядром через dlopen() — автодетект зависимостей portage
# их не видит, поэтому RDEPEND перечисляет КАЖДУЮ библиотеку, к которой
# реально линкуются собранные .so (проверено ldd по сборке 3.6.102):
#   indicator-stack (Indicator-applet3, Messaging-Menu, Status-Notifier,
#   Global-Menu, Indicator-Generic, Sound-Menu) → ayatana-indicator,
#   libdbusmenu[gtk3], ayatana-ido.
#   AlsaMixer + Sound-Effects → alsa-lib; Impulse → libpulse (+fftw);
#   PowerManager → upower-glib; clock → libical; terminal → vte:2.91;
#   weather → json-c; showDesktop → libXrandr; Xgamma → libXxf86vm;
#   keyboard-indicator → libxklavier; slider → libexif; Dbus → python3.
# Сборка с -Denable-* = ON/OFF детерминирует каждую группу. По умолчанию
# включено всё, что есть в системе (стабильный набор), unstable и пакеты
# без Gentoo-аналога (mail/gmenu/sensors) — выключены.
# Recent-Events (Zeitgeist) не предлагается: пакета zeitgeist нет в дереве
# Gentoo, поэтому флага нет — плагин просто не собирается.
IUSE="+indicator3 +alsa +pulse +fftw +upower +ical +keyboard +terminal +weather +xgamma +exif +xrandr +python
	mail gmenu sensors"

RDEPEND=">=x11-misc/cairo-dock-3.6.101
	dev-libs/glib:2
	x11-libs/gtk+:3
	x11-libs/cairo
	gnome-base/librsvg:2
	x11-libs/libX11
	indicator3? (
		dev-libs/libayatana-indicator
		dev-libs/libdbusmenu[gtk3]
		dev-libs/ayatana-ido
	)
	alsa? ( media-libs/alsa-lib )
	pulse? ( media-libs/libpulse )
	fftw? ( sci-libs/fftw )
	upower? ( sys-power/upower )
	ical? ( dev-libs/libical )
	keyboard? ( x11-libs/libxklavier )
	terminal? ( x11-libs/vte:2.91 )
	weather? ( dev-libs/json-c )
	xgamma? ( x11-libs/libXxf86vm )
	exif? ( media-libs/libexif )
	xrandr? ( x11-libs/libXrandr )
	mail? ( net-libs/libetpan )
	gmenu? ( gnome-base/gnome-menus )
	sensors? ( sys-apps/lm-sensors )"

DEPEND="
	${RDEPEND}
	dev-util/intltool
	dev-util/wayland-scanner
	sys-devel/gettext
	virtual/pkgconfig
"

RESTRICT="test"

src_configure() {
	# Основной не-флагаемый набор (rendering, clock, shortcut, switcher,
	# systray, System-Monitor, dustbin, Folders, ...) собирается всегда.
	local mycmakeargs=(
		-Denable-dbusmenu-support=$(usex indicator3 ON OFF)
		-Denable-indicator-support=$(usex indicator3 ON OFF)
		-Denable-libido-support=$(usex indicator3 ON OFF)
		-Denable-global-menu=$(usex indicator3 ON OFF)
		-Denable-alsa-mixer=$(usex alsa ON OFF)
		-Denable-sound-effects=$(usex alsa ON OFF)
		-Denable-impulse=$(usex pulse ON OFF)
		-Denable-upower-support=$(usex upower ON OFF)
		-Denable-ical-support=$(usex ical ON OFF)
		-Denable-keyboard-indicator=$(usex keyboard ON OFF)
		-Denable-terminal=$(usex terminal ON OFF)
		-Denable-weather=$(usex weather ON OFF)
		-Denable-xgamma=$(usex xgamma ON OFF)
		-Denable-exif-support=$(usex exif ON OFF)
		-Denable-xrandr-support=$(usex xrandr ON OFF)
		-Denable-python-interface=$(usex python ON OFF)
		-Denable-mail=$(usex mail ON OFF)
		-Denable-gmenu=$(usex gmenu ON OFF)
		-Denable-sensors-support=$(usex sensors ON OFF)
	)
	# Управляемся с минимумом: остальные enable-* (cairo-penguin, clock,
	# dustbin, gnome/kde/xfce/cosmic-integration, Expander, ...) остаются
	# умолчальными (TRUE), что соответствует сборке из master.
	cmake_src_configure
}