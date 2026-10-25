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
`app-arch/engrampa`, `app-editors/pluma`, `app-text/atril`, `media-gfx/eom`.

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
