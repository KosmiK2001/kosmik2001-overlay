# kosmik2001 overlay

[EN] Gentoo overlay for Fusion Icon 2 — system tray for switching Compiz window managers.
[RU] Gentoo оверлей для Fusion Icon 2 — системный трей для переключения оконных менеджеров Compiz.

## Add overlay / Добавление оверлея

### Method 1: eselect repository / Способ 1: eselect repository

```bash
sudo emerge app-eselect/eselect-repository
sudo eselect repository enable kosmik2001 https://github.com/KosmiK2001/fusion-icon-2-overlay.git
sudo eselect repository sync kosmik2001
```

### Method 2: Manual / Способ 2: Вручную

```bash
sudo mkdir -p /var/db/repos/kosmik2001
sudo git clone https://github.com/KosmiK2001/fusion-icon-2-overlay.git /var/db/repos/kosmik2001
```

## Install / Установка

```bash
sudo emerge --sync kosmik2001
sudo emerge --ask x11-misc/fusion-icon2
```

## USE flags / USE-флаги

| Flag | Default | Description (EN) | Описание (RU) |
|------|---------|------------------|---------------|
| `+file` | Yes | Store settings in plain text config file (~/.config/fusion-icon2/config) | Хранение настроек в текстовом файле |
| `-gsettings` | No | Store settings using GSettings/dconf (mutually exclusive with file) | Хранение настроек через GSettings/dconf (взаимоисключающе с file) |
| `+upx` | Yes | Compress binary with UPX for smaller size | Сжатие бинарника UPX для уменьшения размера |

## Dependencies / Зависимости

- `dev-cpp/gtkmm:3.0` — GTK bindings / GTK привязки
- `gnome-base/librsvg` — SVG rendering / SVG рендеринг
- `media-gfx/imagemagick` — Image conversion / Конвертация изображений
- `dev-libs/glib:2` — GSettings support (optional) / Поддержка GSettings (опционально)

## MATE live (9999) — разработка DE из git

В оверлее лежит набор `-9999` ebuild'ов для MATE: весь `mate-base`, установочный
`mate-extra`, `x11-wm/marco`, `x11-misc/{mate-notification-daemon,mozo}`,
`x11-terms/mate-terminal`, `x11-themes/{mate-icon-theme,mate-backgrounds}`,
`app-arch/engrampa`, `app-editors/pluma`, `app-text/atril`, `media-gfx/eom`,
 плюс `dev-python/python-caja` (привязки Python для расширений Caja) и
`mate-extra/caja-admin` (апстрим — `github.com/infirit/caja-admin`, не
mate-desktop).

Каждый снят с самого свежего релизного ebuild'а из `::gentoo` (его PV указан в
шапке файла) без изменений в зависимостях, USE-флагах, аргументах configure и
фазах — то есть сборка из исходников идёт тем же путём, что и натуральная.

Отличия от релизного ebuild'а ровно три:

1. вместо тарбокса — `EGIT_REPO_URI=https://github.com/mate-desktop/<pn>.git`
   (задаёт `mate-desktop.org.eclass`), ветка `master`;
2. `MATE_BRANCH="1.28"` вместо `$(ver_cut 1-2)`, которое на live даёт 9999:
   одиночный live-пакет собирается против установленной релизной 1.28 MATE и не
   тянет за собой весь DE. Исключения продиктованы самим upstream
   (`configure.ac` master): `mate-settings-daemon` требует `mate-desktop ≥ 1.29.0`,
   `mate-control-center` — `libmarco-private ≥ 1.29.0`, так что эти два тянут
   соответствующий соседний `9999`;
3. патчи `::gentoo`, уже вошедшие в upstream master, убраны (какой именно и
   почему — в шапке каждого ebuild'а).

Подмодуль `mate-submodules` (`mate-panel`, `mate-session-manager`, `mate-utils`,
`caja`) в live-версиях тянет `git-r3`, отдельный тарбокс больше не нужен.

### Теневые `-r1` для python3_14 (`python-caja`, `caja-admin`)

Оба пакета в `::gentoo` объявлены как `PYTHON_COMPAT=( python3_{11..13} )`, а
система собрана с единственным `PYTHON_SINGLE_TARGET=python3_14` —
`REQUIRED_USE="${PYTHON_REQUIRED_USE}"` не выполняется, пакет неустанавливаем.
В оверлее лежат копии тех же ebuild'ов с `python3_{11..14}` (релизный `-r1` и
`9999`), остальное без изменений. Проверено на 3.14.7: `python-caja`
конфигурируется на 3.14 (`Python version ... 3.14`), `libcaja-python.so` линкуется с
`libpython3.14.so.1.0`, расширение `caja-admin.py` байткомпилится
(`cpython-314.pyc`) и загружается с настоящим `Caja`-typelib (GInterface
`MenuProvider` разрешается). Удалить эти файлы, когда апстрим поднимет диапазон.

### Установка одного пакета

```bash
echo '=mate-base/mate-panel-9999 **' | sudo tee /etc/portage/package.accept_keywords/mate-live
sudo emerge --ask --noreplace =mate-base/mate-panel-9999
```

`**` — ключевое слово live-ebuild'ов; без него ebuild замаскирован.

### Ловушка: метапакет `mate`

Установленный `mate-base/mate-1.28.0` пинит `=mate-base/mate-panel-1.28*` и
так далее по всему DE, поэтому live-версия любого из этих пакетов даёт slot
conflict. Вариантов два:

* перевести на git весь DE: `sudo emerge -1 =mate-base/mate-9999` (live
  метапакет тоже в оверлее; `x11-themes/mate-themes` остаётся релизным — это
  только оформление, слот `0/3.22`);
* или снять метапакет: `sudo emerge --deselect mate-base/mate && sudo emerge -C mate-base/mate`
  — тогда любой одиночный live-пакет ставится свободно. Возврат:
  `sudo emerge -1 =mate-base/mate-1.28.0`.

### Своё зеркало, ветка или коммит — основной инструмент разработки

`git-r3` переопределяет координаты по имени репозитория (суффикс переменной —
имя репо в верхнем регистре, все не-буквенно-цифровые символы → `_`):

```bash
# /etc/portage/env/mate-live.conf
EGIT_OVERRIDE_REPO_MATE_PANEL="https://github.com/KosmiK2001/mate-panel.git"
EGIT_OVERRIDE_BRANCH_MATE_PANEL="pr/tray-overflow"
# EGIT_OVERRIDE_COMMIT_MATE_PANEL="v1.28.7" — собрать конкретный тег/коммит

# /etc/portage/package.env
mate-base/mate-panel mate-live
```

Локальный клон вместо GitHub (правки подхватываются после `git commit`, сеть не
нужна):

```bash
EGIT_OVERRIDE_REPO_MATE_PANEL="/home/kosmik2001_dir/Документы/GLM-5.3-Kimi/mate-panel"
```

Флаги для отладки:

```bash
# /etc/portage/env/mate-debug.conf
CFLAGS="-O0 -g3"
CXXFLAGS="-O0 -g3"
FEATURES="splitdebug keepdebug"
```

Кэш клонов — `$(portageq envvar DISTDIR)/git3-src` (`EGIT3_STORE_DIR`): повторный
`emerge -1 =...-9999` делает только fetch+checkout, поэтому пересборка быстрая.
Полностью пересоздать репозиторий:
`rm -rf $(portageq envvar DISTDIR)/git3-src/github.com_mate-desktop_mate-panel.git`.

Быстрый цикл правок без установки в систему:

```bash
sudo ebuild /var/db/repos/kosmik2001/mate-base/mate-panel/mate-panel-9999.ebuild clean unpack compile
# результат в /var/tmp/portage/mate-base/mate-panel-9999/work/, система не тронута
```

Пересобрать и поставить уже установленный live-пакет (PV тот же — `emerge -1`
скажет «0 of 0», ничего не сделает):

```bash
sudo ebuild /var/db/repos/kosmik2001/mate-base/mate-panel/mate-panel-9999.ebuild clean install qmerge
```

### Порядок первой сборки

`mate-common-9999` — фундамент: он ставит `/usr/bin/mate-doc-common`,
`mate-autogen` и m4-макросы в `aclocal`, без которых `mate.eclass` на фазе
`prepare` падает с `mate-doc-common: command not found` (для `PV=9999` он
принудительно гоняет `ematedocize`). Поэтому первым — `mate-common-9999`, и
только потом остальное.

## MATE на Wayland

Сессия для отладки Wayland: `mate-extra/mate-wayland-session` ставит
`/usr/share/wayland-sessions/mate-wayland.desktop` (появится в меню любого DM,
включая sddm) и обёртку `/usr/bin/mate-wayland-session`.

### Флаг `wayland` обязателен, иначе тихий X11

У `caja`, `mate-settings-daemon`, `mate-media`, `mate-power-manager`,
`mate-utils`, `mate-panel` и `mate-notification-daemon` в `configure.ac` есть
`AC_ARG_ENABLE([wayland])` **со значением по умолчанию `auto`**: при наличии
`gtk-layer-shell-0` / `wayland-client` / `gdk-wayland-3.0` поддержка
включается, при отсутствии — молча выключается, и «сборка прошла успешно»
ничего не означает. Поэтому в оверлее у всех семи есть явный флаг `wayland`:

```bash
# /etc/portage/package.use/mate-wayland
mate-base/caja                    wayland
mate-base/mate-panel              wayland
mate-base/mate-settings-daemon    wayland
mate-extra/mate-media             wayland
mate-extra/mate-power-manager     wayland
mate-extra/mate-utils             wayland
x11-misc/mate-notification-daemon wayland
```

Проверить, что wayland действительно собран, — по линковке бинарника:

```bash
ldd /usr/bin/caja /usr/bin/mate-panel /usr/bin/mate-notification-daemon \
    /usr/bin/mate-volume-control-applet /usr/bin/mate-power-manager \
    /usr/bin/mate-screenshot /usr/libexec/mate-settings-daemon \
  | grep -E "wayland|gtk-layer-shell|xfce4windowing"
```

Если `libwayland-client.so` в выводе нет — пакет собран X11-only, независимо
от того, что написало `emerge`.

### Апплеты: только in-process

Главное открытие headless-прогона: **под Wayland не работает ни один
out-of-process апплет**. Панель запускает апплет через D-Bus-фабрику, а
`libmate-panel-applet` умеет это только на X11:

```
** (wnck-applet): WARNING **: Requested out-of-process applet, which is only supported on X11
dbus-daemon: Activated service 'org.mate.panel.applet.WnckletFactory' failed:
             Process ... exited with status 1
```

То же для `clock-applet` и `notification-area-applet`. А по умолчанию все
апплеты собираются именно out-of-process — это дефолт upstream:

| пакет | ключ configure | дефолт |
|---|---|---|
| `mate-panel` | `--with-in-process-applets=clock,fish,notification-area,wncklet,all` | `none` |
| `mate-applets` | `--enable-in-process` | `no` |
| `mate-media` | `--enable-in-process` | следует за `wayland` |
| `mate-utils` | `--enable-in-process` | `no` |
| `mate-sensors-applet` | `--enable-in-process` | `no` |
| `mate-notification-daemon` | `--enable-in-process` | `no` |

В оверлее:

```bash
# /etc/portage/package.use/mate-wayland
mate-base/mate-applets        in-process
mate-extra/mate-sensors-applet in-process
```

плюс `mate-panel-9999` получает `--with-in-process-applets=$(usex wayland all none)`,
а `mate-media`, `mate-utils`, `mate-notification-daemon` —
`$(use_enable wayland in-process)`. In-process апплеты работают и на X11,
теряется только изоляция падений, поэтому обычная сборка не ломается.

### Что внутри сессии

Композитор — `labwc` (wlroots). `GDK_BACKEND=wayland` выставлен **без**
`x11`-фолбэка: GTK-приложение, которое ещё не умеет Wayland, падает с ошибкой
в журнале, а не уползает молча в XWayland. Для мягкого сравнения —
`GDK_BACKEND=wayland,x11` в `/usr/bin/mate-wayland-session`.

`mate-session-manager` в сессии **участвует** — иначе завершение сеанса не
работает в принципе. Кнопка «Выход» в панели не вызывает `mate-session-save`:
она делает D-Bus-вызов `Logout(u)` на `org.gnome.SessionManager`
(`mate-panel/libpanel-util/panel-session-manager.c:88`). Это имя берёт
`mate-session` (`mate-session/main.c:78`), он же раздаёт
`/etc/xdg/autostart` и обязательные компоненты `panel='mate-panel'`,
`filemanager='caja'`.

Оконного менеджера в Wayland-сессии нет (WM — композитор), но `mate-session`
всё равно запускает его через `data/mate-wm`, а тот при пустом
`org.mate.session.required-components windowmanager` ищет в `PATH` **marco**.
Поэтому `WINDOW_MANAGER` указывает на `/usr/bin/mate-wayland-wm-stub` —
заглушку, которая просто висит, пока жива сессия.

После выхода `mate-session` autostart вызывает `labwc --exit`, иначе остаётся
пустой экран с живым композитором. Если `mate-session` не поднимется,
компоненты запускаются напрямую — сессия не остаётся пустой, но без
завершения сеанса.

**Две правки mate-session, без которых он падал с SIGSEGV** на Wayland
(патч `mate-session-manager-9999-wayland-x11-guards.patch`):

| файл | что было |
|---|---|
| `mate-session/msm-gnome.c` | `msm_compat_gnome_smproxy_startup/shutdown` зовут `GDK_DISPLAY_XDISPLAY()` + `RootWindow()` без проверки типа дисплея (smproxy — X11-хак с `GNOME_SM_PROXY` на корневом окне) |
| `mate-session/gs-idle-monitor.c` | `gs_idle_monitor_constructor` зовёт `_init_xtest()`/`init_xsync()` → `XLockDisplay (GDK_DISPLAY_XDISPLAY (...))`, `XSyncQueryExtension` и т.д. |

Бэктрейс из core снимается так:

```bash
coredumpctl dump <pid> --output=/tmp/core.ms
eu-stack --core /tmp/core.ms -e /usr/bin/mate-session
```

**Фаза startup занимает ~30 с.** Пока `mate-session` не перешёл в фазу
`Running`, `Logout` отбивается ошибкой
`org.gnome.SessionManager.NotInRunning: Shutdown interface is only available
during the Running phase`. Причина — обязательные компоненты: `caja` на
Wayland не регистрируется как клиент сеанса и не сообщает о готовности, так
что сессия висит в startup до таймаута. Практический эффект: сразу после
входа кнопка «Выход» не сработает, через полминуты — работает. Это
следующая задача для патча (не ждать `filemanager` в Wayland-сессии).

Выход вручную, если понадобится: `labwc --exit`.

**Пути только абсолютные**: `mate-settings-daemon`, `mate-notification-daemon`
и `polkit-mate-authentication-agent-1` лежат в `/usr/libexec`, не в `/usr/bin`.
Вызов по имени из autostart даёт молчаливый `command not found`, и половина
сессии не поднимается, при этом сама сессия выглядит живой.

### Что проверено headless-прогоном

Запуск без DRM (`WLR_BACKENDS=headless WLR_RENDERER=pixman`), чтобы не трогать
рабочую сессию:

```bash
export XDG_RUNTIME_DIR=/tmp/xdg-wl-test && mkdir -p $XDG_RUNTIME_DIR
WLR_BACKENDS=headless WLR_RENDERER=pixman \
  dbus-run-session -- labwc -C /usr/share/mate-wayland/labwc
```

Живыми поднимаются: `labwc`, `/usr/libexec/mate-settings-daemon`, `mate-panel`,
`/usr/libexec/mate-notification-daemon`,
`/usr/libexec/polkit-mate-authentication-agent-1`, `caja -n` (см. ниже),
порталы, gvfs, at-spi, dconf, keyring.

Апплеты действительно грузятся in-process — видно по карте памяти панели:

```
$ grep -oE "/usr/[^ ]*\.so" /proc/$(pgrep -x mate-panel)/maps | grep applet
/usr/lib64/mate-panel/libclock-applet.so
/usr/lib64/mate-panel/libnotification-area-applet.so
/usr/lib64/mate-panel/libwnck-applet.so
```

### Известные дыры (то, что и надо патчить)

- `mate-session-manager` — нет Wayland-режима: старт WM, logout, autostart.
  Без него на шине нет `org.gnome.SessionManager`, и это видно по журналу:
  `mate-settings-daemon` не может ни зарегистрировать клиента, ни выставить
  `QT_FONT_DPI`/`QT_SCALE_FACTOR`, `GrabMediaPlayerKeys` не работает;
  `polkit-mate-authentication-agent-1` тоже не регистрируется. То есть
  `mate-session` нужен не только для logout — на нём висит интеграция демонов.
- `marco` — X11-only, под Wayland не запускается вообще (WM = композитор).
- `mate-screensaver` — X11-only (`XScreenSaver` extension).
- `mate-desktop` (`mate-bg`) — фон рисуется через X11/Xrandr.
- `caja -n` — стартует и сразу выходит (нет рабочего стола на Wayland), поэтому
  ни файлового менеджера-демона, ни иконок на рабочем столе. `caja` без `-n`
  под Wayland пути не имеет вовсе.
- Апплеты — только in-process (см. выше); out-of-process на Wayland не
  поддерживается в принципе, и это надо чинить в `libmate-panel-applet`
  (D-Bus-фабрика + `panel-applet-container`), иначе сторонние апплеты
  (sensors, indicator, сторонние .so) под Wayland не завести. Три апплета
  остаются out-of-process и на Wayland не загрузятся: `BrightnessApplet`,
  `InhibitApplet`, `PowerProfilesApplet` — они из `mate-power-manager`, у
  которого нет ключа `--enable-in-process`.
- `libxfce4windowing`: `Window<->Workspace association is not available on your
  compositor` — labwc не реализует `ext-workspace-v1`, поэтому связка
  окно↔рабочее место в `window-list`/`workspace-switcher` деградирует.

## Три Wayland-сессии: что выбрать

В оверлее теперь три пакета, и все три можно держать установленными — они
ставят разные файлы и дают разные пункты в меню DM.

| пункт в sddm | пакет | композитор | менеджер сеанса | «Выход» в панели |
|---|---|---|---|---|
| **MATE (Wayland)** | `mate-base/mate-session-manager-9999` + PR #340 | wayfire | `mate-session` | работает |
| MATE (Wayland, без менеджера сеанса) | `mate-extra/mate-wayland-session-9999` | wayfire | нет | не работает |
| MATE on Wayland (labwc) | `mate-extra/mate-wayland-session-labwc` | labwc | `mate-session` + заглушка WM | работает, но фаза startup ~30 с |
| MATE (Wayland, dev-сборка) | `mate-extra/mate-wayland-dev-session` | wayfire | `mate-session` | работает — тот же `startmatewayland`, но из `~/mate-dev` |

**Выбор: «MATE (Wayland)»** — это апстрим-PR
[mate-session-manager#340](https://github.com/mate-desktop/mate-session-manager/pull/340),
наложенный на live-ebuild. Он делает то же, что наша labwc-сессия, но
внутри `mate-session`.

### Что даёт PR #340 (проверено headless)

- `startmatewayland` запускает wayfire с приватной копией конфига
  `~/.config/mate/wayfire/wayfire.ini` (шаблон — `/usr/share/mate-session-manager/wayfire.ini`);
- в `[autostart]` wayfire стоит `session = mate-session; killall wayfire` —
  сессия живёт как ребёнок композитора, и когда она кончается, wayfire умирает
  сам, greeter возвращается без всяких watchdog'ов;
- на Wayland пропускаются required-components
  (`main: skipping '%s' required component on Wayland`) — это лечит нашу
  проблему с `caja`, из-за которой сессия висела в startup;
- `GSM_MANAGER_PHASE_TIMEOUT_WAYLAND = 3` секунды: `IsSessionRunning` возвращает
  `(true,)` уже через 12 с после старта, а не через 30;
- `org.gnome.SessionManager` на шине, `Logout(u)` работает:
  `Logout(2)` гасит сессию целиком (проверено — через 8 с не остаётся ни
  `mate-session`, ни `wayfire`, ни `mate-panel`);
- idle-монитор через `ext-idle-notify-v1` вместо XSync/XTest;
- в нём же X11-guard'ы для `msm-gnome.c` и `gs-idle-monitor.c`, из-за которых
  mate-session падал с SIGSEGV — наши собственные патчи после этого удалены.

### Чего не хватает в Gentoo для wayfire-сессий

- **Плагин `ext-workspace` не собирается**: в `/usr/lib64/wayfire/` есть только
  `libforeign-toplevel.so` и `libidle.so`, а шаблон `wayfire.ini` из PR его
  подключает → `Failed to load plugin "ext-workspace"`. Следствие: связка
  окно↔рабочее место в пейджере панели неполная. Пакета
  `gui-wm/wayfire-plugins-extra` в дереве нет.
- `gui-wm/wayfire` ставит дефолтный конфиг как `/usr/share/wayfire/wayfire.ini`
  и не создаёт `examples/` — поэтому апстримный `mate-wayland.sh` (из
  `mate-wayland-session`) нуждается в патче, иначе `cp` молча падает и сессия
  стартует пустым Wayfire без компонентов MATE. Патч в оверлее есть.
- `wayfire` отказывается стартовать от root (`Unable to drop root`), а также
  требует GLES2: под `WLR_RENDERER=pixman` плагины cube/invert/switcher
  не грузятся. Для headless-тестов это нормально, для реальной сессии
  нужен DRM.


## Dev-сессия: сборка всего MATE в приватный префикс

Четвёртый пункт в sddm — `MATE (Wayland, dev-сборка)` — запускает ту же
wayfire-сессию, что и системную, но с окружением, поднятым на приватный
префикс `~/mate-dev`. Системные файлы не трогаются: можно проверять сборку
**любого** компонента MATE (не только панели), а рабочая сессия остаётся
на системных пакетах.

### Наполнение префикса

```sh
sudo mate-dev-build mate-base/mate-panel        # один пакет
sudo mate-dev-build mate-base/caja mate-extra/mate-media
sudo mate-dev-build --all                       # всё live-содержимое оверлея
sudo mate-dev-build --list                      # что доступно
sudo mate-dev-build --clean                     # снести префикс
```

Сборка идёт **штатным ebuild'ом** — те же USE-флаги, те же фазы, тот же
`configure`/`meson`, что и у системной сборки. Отличие одно: вместо `qmerge`
образ portage (`/var/tmp/portage/<cat>/<pn>-9999/image/`) копируется в
`~/mate-dev`, после чего перекомпилируются схемы gsettings и кэш иконок.
Раскладка префикса — как у `/`: `usr/bin`, `usr/lib64`, `usr/share`.

Из ssh-сессии root переменная `SUDO_USER` пуста, поэтому префикс надо задать
явно: `MATE_DEV_PREFIX=/home/<пользователь>/mate-dev`.

### Что подменяет сессия

`/usr/bin/start-mate-wayland-dev` выставляет и делает `exec startmatewayland`:

| переменная | значение |
|---|---|
| `PATH` | `$PREFIX/usr/bin:$PATH` |
| `LD_LIBRARY_PATH` | `$PREFIX/usr/lib64:$PREFIX/usr/lib:...` |
| `XDG_DATA_DIRS` | `$PREFIX/usr/share:/usr/local/share:/usr/share` |
| `GSETTINGS_SCHEMA_DIR` | `$PREFIX/usr/share/glib-2.0/schemas` |
| `GI_TYPELIB_PATH` | `$PREFIX/usr/lib64/girepository-1.0` |
| `XDG_CONFIG_DIRS` | `$PREFIX/generated:/etc/xdg` |

`$PREFIX/generated/autostart/*.desktop` — копии `/etc/xdg/autostart` с
переписанными `Exec=`/`TryExec=`: если бинарь есть в префиксе, путь ведёт в
префикс, иначе остаётся `/usr/...`. Без этого `mate-session` запускал бы
системные `mate-settings-daemon`, `mate-notification-daemon` и т.д., и
тестовая сборка этих пакетов не проверялась бы вообще.

### Журнал

`~/mate-dev/session.log` после каждой dev-сессии: какой префикс, откуда
взялся каждый ключевой бинарь (`mate-session`, `mate-panel`, `msd`, `caja`,
`mnd`), какие модули апплетов лежат в префиксе и куда разрешается
`libmate-panel-applet` у модуля панели. Если в журнале пути из `/usr/...` —
значит, компонент в префикс не собирали, и сессия его не проверяет.

### Ограничения

- в префикс попадает только то, что собрано `mate-dev-build`; всё остальное
  берётся из `/usr` — это нормально и есть суть схемы;
- dconf общий с рабочей сессией: настройки, изменённые в dev-сессии, останутся
  и в системной (отдельный профиль не заводится намеренно — иначе тест
  описывал бы не ту конфигурацию);
- `mate-terminal` одноэкземплярный: после обновления бинаря старый процесс
  продолжает работать со старым кодом, для проверки нужен
  `mate-terminal --disable-factory` или закрыть все окна.
