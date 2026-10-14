#!/bin/bash
#=====================================================================
# qt-debundle.sh — собрать Qt 6.11.0 из исходников и подложить в /opt/max
# вместо вендорских библиотек (контроль происхождения собранных либ).
#
# НИЧЕГО НЕ УСТАНАВЛИВАЕТ В СИСТЕМУ:
#   * сборка идёт ebuild-фазами (clean unpack compile install) — image
#     остаётся в /var/tmp/portage/dev-qt/qtbase-6.11.0/image, пакет в
#     /var/db/pkg не регистрируется;
#   * собранные libQt6*.so.6 копируются в /opt/max/lib64, вендорские
#     оригиналы переезжают в бэкап КАТАЛОГА ПРОЕКТА (не системы);
#   * откат: --restore (мгновенно) либо emerge -1 net-im/max (штатно,
#     deb снова отдаст вендорские либы).
#
# Почему qtbase-only: приватный ABI Qt маркируется версией qtbase, против
# которого собран МОДУЛЬ (QtPrivate_6_11_0 vs 6_11_2). Вендорские модули
# (Quick/Qml/WebEngine/Multimedia/Svg...) собраны против вендорского 6.11.0
# и уже совместимы с нашим собранным 6.11.0 — первый swap-тест это доказал.
# Каждый доп. модуль (например qtsvg) надо собирать ПРОТИВ нашего image
# qtbase, а не против системного 6.11.2 (иначе получит маркеры 6_11_2).
#
# Использование:
#   ./qt-debundle.sh                     собрать при необходимости + подложить + проверить
#   ./qt-debundle.sh deploy --with-svg   то же + собрать qtsvg-6.11.0 против stage и подложить
#   ./qt-debundle.sh --restore           вернуть вендорские либы из бэкапа
#   ./qt-debundle.sh --rebuild           пересобрать qtbase даже если image свежий
#=====================================================================
set -u

MODE="${1:-deploy}"   # deploy | restore | rebuild
WITH_SVG=0
[ "${2:-}" = --with-svg ] && WITH_SVG=1

# Пути переопределяются env'ом (QT_DEBUNDLE_*); по умолчанию выбираются
# автоматически: если каталог хелпера доступен на запись (запуск из проекта
# Max/) — рабочие каталоги рядом с ним, иначе (установлен в root-only
# /usr/libexec/max-debundle, запуск пользователем) — /var/lib/max и /var/tmp.
PROJ_ROOT="${QT_DEBUNDLE_PROJ_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
if [ -w "$PROJ_ROOT" ]; then
  DEF_BACKUP="$PROJ_ROOT/qt-vendor-backup"
  DEF_STAGE="$PROJ_ROOT/../temps/qt-stage"
  DEF_WORK="$PROJ_ROOT/../temps"
else
  DEF_BACKUP=/var/lib/max/qt-vendor-backup
  DEF_STAGE=/var/tmp/qt-stage
  DEF_WORK=/var/tmp/qt-debundle-work
fi
OVERLAY="${QT_DEBUNDLE_OVERLAY:-}"
# если OVERLAY не задан — ищем ebuild'ы в известных местах
if [ -z "$OVERLAY" ]; then
  for cand in "$PROJ_ROOT/../temps/overlay-work" /var/db/repos/kosmik2001; do
    [ -f "$cand/dev-qt/qtbase/qtbase-6.11.0.ebuild" ] && { OVERLAY="$cand"; break; }
  done
fi
BACKUP="${QT_DEBUNDLE_BACKUP:-$DEF_BACKUP}"
STAGE_DIR="${QT_DEBUNDLE_STAGE:-$DEF_STAGE}"
QT_EBUILD="$OVERLAY/dev-qt/qtbase/qtbase-6.11.0.ebuild"
B=/opt/max/lib64
IMAGE=/var/tmp/portage/dev-qt/qtbase-6.11.0/image/usr/lib64
# модули qtbase, которые есть и в бандле max (Svg — это qtsvg, отдельный пакет)
QT_LIBS="libQt6Core libQt6Gui libQt6Network libQt6DBus libQt6Widgets libQt6Xml libQt6Concurrent libQt6OpenGL libQt6XcbQpa"
LOG="${QT_DEBUNDLE_LOG:-$HOME/.cache/max-debundle.log}"

need_root() { sudo -n true 2>/dev/null || { echo "ERR: нужен passwordless sudo (sudo -n)"; exit 1; }; }

build_qtbase() {
  [ -f "$QT_EBUILD" ] || { echo "ERR: нет ebuild'а: $QT_EBUILD"; exit 1; }
  need_root
  echo "== сборка qtbase-6.11.0 (ebuild-фазы, ~7 мин на 32 ядрах, ccache) =="
  sudo -n ebuild "$QT_EBUILD" manifest 2>&1 | tail -1
  sudo -n ebuild "$QT_EBUILD" clean unpack compile install 2>&1 | tail -2 \
    || { echo "ERR: сборка упала"; exit 1; }
}

image_ready() {
  # /var/tmp/portage root-only — проверять через sudo
  sudo -n test -f "$IMAGE/libQt6Core.so.6.11.0" && sudo -n test -f "$IMAGE/libQt6Gui.so.6.11.0"
}

# Сборка qtsvg-6.11.0 ПРОТИВ нашего image qtbase (не системного 6.11.2!).
# Приватные маркеры модуля берутся от версии qtbase, против которого он собран
# (QtPrivate_6_11_0). Рецепт (проверено): stage-копия image с раскладкой usr/...,
# CMAKE_FIND_ROOT_PATH + MODE_PACKAGE=ONLY (только он!), явные -DQt6*_DIR.
SVG_SRC=""
SVG_IMAGE=/var/tmp/portage/dev-qt/qtsvg-6.11.0/image/usr/lib64
S="${QT_DEBUNDLE_WORK:-$DEF_WORK}"   # рабоч. каталог сборки (src/build/install qtsvg)
build_svg() {
  local dist qtsvg_tar
  qtsvg_tar="$(sudo -n find /home /var/cache -name 'qtsvg-everywhere-src-6.11.0.tar.xz' 2>/dev/null | head -1)"
  [ -n "$qtsvg_tar" ] || { echo "ERR: нет тарбола qtsvg (нужен ebuild dev-qt/qtsvg-6.11.0 manifest)"; exit 1; }
  need_root
  # 1) stage-копия qtbase-image (root-only исходник; каталоги могут быть в
  #    /var/tmp, chown юзеру, чтобы cmake/ninja работали от него)
  sudo -n rm -rf "$STAGE_DIR" "$S"
  sudo -n mkdir -p "$STAGE_DIR/usr" "$S"
  sudo -n cp -a "/var/tmp/portage/dev-qt/qtbase-6.11.0/image/usr/." "$STAGE_DIR/usr/"
  sudo -n chown -R "$(id -un)" "$STAGE_DIR" "$S"
  # 2) распаковка исходников qtsvg
  mkdir -p "$S/qtsvg-src"; tar -xf "$qtsvg_tar" -C "$S" 2>/dev/null
  rm -rf "$S/qtsvg-src"; mv "$S/qtsvg-everywhere-src-6.11.0" "$S/qtsvg-src"
  # 3) cmake против stage
  rm -rf "$S/qtsvg-build" "$S/qtsvg-install"; mkdir -p "$S/qtsvg-build" "$S/qtsvg-install"
  cmake -S "$S/qtsvg-src" -B "$S/qtsvg-build" -G Ninja \
    -DCMAKE_FIND_ROOT_PATH="$STAGE_DIR" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DQt6_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6" \
    -DQt6Core_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6Core" \
    -DQt6CorePrivate_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6CorePrivate" \
    -DQt6CoreTools_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6CoreTools" \
    -DQt6Gui_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6Gui" \
    -DQt6GuiTools_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6GuiTools" \
    -DQt6Widgets_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6Widgets" \
    -DQt6WidgetsTools_DIR="$STAGE_DIR/usr/lib64/cmake/Qt6WidgetsTools" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DCMAKE_INSTALL_PREFIX="$S/qtsvg-install" -DCMAKE_BUILD_TYPE=Release \
    -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DCMAKE_CXX_FLAGS="-O2" \
    >/dev/null || { echo "ERR: cmake qtsvg упал"; exit 1; }
  grep -q 'libQt6Svg' "$S/qtsvg-build/build.ninja" || { echo "ERR: в ninja нет целей Svg"; exit 1; }
  ninja -C "$S/qtsvg-build" >/dev/null || { echo "ERR: сборка qtsvg упала"; exit 1; }
  # install может ругаться на .prl (некритично — нам нужна только .so);
  # критично, чтобы сама библиотека установилась
  ninja -C "$S/qtsvg-build" install >/dev/null 2>&1 || true
  [ -e "$S/qtsvg-install/lib64/libQt6Svg.so.6.11.0" ] \
    || { echo "ERR: libQt6Svg.so.6.11.0 не установилась"; exit 1; }
  # 4) контроль приватного ABI
  local lib="$S/qtsvg-install/lib64/libQt6Svg.so.6.11.0"
  nm -D "$lib" 2>/dev/null | grep -q QtPrivate_6_11_0 \
    && echo "   qtsvg: QtPrivate_6_11_0 OK" \
    || { echo "ERR: qtsvg собран не против нашего qtbase (маркер не 6_11_0)"; exit 1; }
  SVG_IMAGE="$S/qtsvg-install/lib64"
}

deploy() {
  need_root
  sudo -n mkdir -p "$BACKUP" || { echo "ERR: не могу создать $BACKUP"; exit 1; }
  # 1) сборка, если image нет или просят пересобрать
  if [ "$MODE" = rebuild ] || ! image_ready; then build_qtbase; fi
  echo "== проверка версии и приватного ABI в собранном qtbase =="
  sudo -n nm -D "$IMAGE/libQt6Core.so.6.11.0" 2>/dev/null | grep -qc QtPrivate_6_11_0 \
    && echo "   QtPrivate_6_11_0: OK (совместимо с вендорскими модулями 6.11.0)" \
    || { echo "ERR: в собранном qtbase нет QtPrivate_6_11_0 — ABI не тот, стоп"; exit 1; }

  # 2) бэкап вендорских для затрагиваемых либ
  echo "== бэкап вендорских либ в $BACKUP =="
  mv_backed=0
  for l in $QT_LIBS; do
    for f in "$B/$l".so.6*; do
      [ -e "$f" ] || [ -L "$f" ] || continue
      [ -e "$BACKUP/$(basename "$f")" ] && continue   # уже в бэкапе
      sudo -n mv "$f" "$BACKUP/" || { echo "ERR: mv $f -> $BACKUP"; exit 1; }
      mv_backed=$((mv_backed+1))
    done
  done
  if [ "$WITH_SVG" = 1 ]; then
    build_svg
    for f in "$B"/libQt6Svg.so.6*; do
      [ -e "$f" ] || [ -L "$f" ] || continue
      [ -e "$BACKUP/$(basename "$f")" ] && continue
      sudo -n mv "$f" "$BACKUP/" || { echo "ERR: mv $f -> $BACKUP"; exit 1; }
      mv_backed=$((mv_backed+1))
    done
  fi
  echo "   забэкаплено: $mv_backed"

  # 3) подложка собранных
  echo "== подложка собранных libQt6 в $B =="
  placed=0
  for l in $QT_LIBS; do
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      sudo -n cp -P "$f" "$B/"
      placed=$((placed+1))
    done < <(sudo -n find "$IMAGE" -maxdepth 1 -name "$l.so.6*" 2>/dev/null)
  done
  if [ "$WITH_SVG" = 1 ]; then
    for f in "$SVG_IMAGE"/libQt6Svg.so.6*; do
      [ -e "$f" ] || [ -L "$f" ] || continue
      case "$f" in *SvgWidgets*) continue;; esac   # в бандле нет SvgWidgets
      sudo -n cp -P "$f" "$B/"
      placed=$((placed+1))
    done
  fi
  echo "   подложено: $placed"
  ls -la "$B"/libQt6Core.so.6* | awk '{print "   " $NF, $5}' | head -2

  # 4) проверка запуском
  echo "== проверка: запуск max ~35с =="
  cd "$PROJ_ROOT/.." || exit 1
  export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
  timeout 35 /usr/bin/max > "$LOG" 2>&1
  rc=$?
  undef=$(grep -cE 'undefined symbol|cannot open shared object' "$LOG")
  echo "   rc=$rc (124=жил) | undefined: $undef"
  [ $rc -eq 124 ] && [ "$undef" -eq 0 ] \
    && echo "   OK: приложение живёт на собранном qtbase" \
    || echo "   ПРОВАЛ — откатываю: ./qt-debundle.sh --restore"
}

restore() {
  need_root
  if sudo -n [ -z "$(sudo -n ls -A "$BACKUP" 2>/dev/null)" ]; then
    echo "ERR: бэкап $BACKUP пуст или отсутствует — НЕ сношу подложенные либы"
    echo "    (venedorские можно восстановить: emerge -1 =net-im/max или из image сборки)"
    exit 1
  fi
  echo "== откат: вендорские либы из $BACKUP обратно в $B =="
  # сначала убрать подложенные (и любые libQt6 из списка, не вендорские)
  for l in $QT_LIBS libQt6Svg; do
    sudo -n rm -f "$B/$l".so.6* 2>/dev/null
  done
  restored=0
  for f in "$BACKUP"/*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    sudo -n mv -f "$f" "$B/" || { echo "ERR: mv -f $f -> $B"; exit 1; }
    restored=$((restored+1))
  done
  echo "   восстановлено: $restored"
  echo "   в lib64: $(sudo -n ls "$B" | wc -l) файлов (ожидается 175 при r10, 179 при r9)"
}

case "$MODE" in
  deploy|rebuild|--deploy|--rebuild) deploy ;;
  restore|--restore)                 restore ;;
  *) echo "usage: $0 [deploy|rebuild|restore]"; exit 1 ;;
esac