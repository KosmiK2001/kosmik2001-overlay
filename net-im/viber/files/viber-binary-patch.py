#!/usr/bin/env python3
"""Временные бинарные патчи для проприетарного /opt/viber/Viber.

Viber для Linux хранит свои QML-файлы вшитыми в бинарник И текстом, и
AOT-скомпилированными единицах (QmlCacheGeneratedCode... в бинаре); Qt по
умолчанию грузит AOT, поэтому одного текстового патча мало — обёртка
/usr/bin/viber обязанно ставит QML_DISABLE_DISK_CACHE=1 (маркер
/opt/viber/.viber-tray-patched кладёт ebuild), тогда Qt перекомпилирует
QML из пропатченного текста (+~1.2 с к старту).
Qt6 moc-строки фиксируются по смещениям, QML-блоки в ресурсе имеют
4-байтный BE-префикс длины — поэтому любой патч здесь строго той же длины;
Скрипт проверяет длину и падает при расхождении.

--tray-toggle
  Labs.SystemTrayIcon.onActivated всегда вызывал ViberApp.requestActivate(),
  поэтому повторный левый клик по трей-иконке не прятал окно обратно в трей.
  Становится toggle: Trigger(3)/DoubleClick(2) -> если окно видимо,
  скрыть (ViberApp.window.hide() — слот QWindow, именно hide(), а не
  visible=false: так делает whatsapp-desktop в app/main.js), иначе
  показать/активировать. Нуль-гард w&&: если window вдруг nullptr —
  падаем в requestActivate (старое поведение), а не в TypeError.
  Context(1)/MiddleClick(4) игнорируются (для контекста есть меню).
  ViberApp.window — Q_PROPERTY(QWindow*), в самом Viber он уже
  используется как `ViberApp.window.height`, так что обращение валидно.

--notif-ignore
  LinuxNotificationCenter подписывается на ActionInvoked общего
  org.freedesktop.Notifications БЕЗ проверки, чьё это уведомление.
  mate-notification-daemon (mnd-daemon.c: window_clicked_cb ->
  _action_invoked_cb -> notify_daemon_notifications_emit_action_invoked)
  эмитит ActionInvoked на клик по ЛЮБОму уведомлению, поэтому клик по
  чужому уведомлению в общем трее MATE поднимал окно Viber.
  Подписка ломается переименованием слота в несуществующий:
  QDBusConnection::connect() просто вернёт false (см. 0x911e6b:
  lea rcx, "1onActionInvoked(quint32, QString)" -> call connect).
  САЙД-ЭФФЕКТ: клик по СОБСТВЕННОМУ уведомлению Viber перестанет открывать
  чат — окно поднимается кликом по трей-иконке (--tray-toggle).

--soft
  Паттерн не найден -> предупреждение и код возврата 2 вместо FATAL.
  Для live-ebuild (viber-9999): апстрим может переписать QML/moc, и сборка
  нового релиза не должна вставать из-за патча.

Использование: viber-binary-patch.py [--tray-toggle] [--notif-ignore] [--soft] <файл>
"""
import sys

TRAY_OLD = (b"    onActivated: function(reason) {\n"
            b"        if (!ViberApp.OSInfo.isMacOS && reason !== Labs.SystemTrayIcon.Context)\n"
            b"            ViberApp.requestActivate()\n"
            b"    }\n")

_TRAY_NEW_CORE = (b"    onActivated: function(r) {\n"
                  b"        if (r===2||r===3) { var w=ViberApp.window; w&&w.visible?w.hide():ViberApp.requestActivate() }\n"
                  b"    }\n")

NOTIF_OLD = b"1onActionInvoked(quint32, QString)"
NOTIF_NEW = b"1noActionInvoked(quint32, QString)"


def tray_new():
    """Выровнять новый хендлер по длине старого (трailing-пробелы в строке if)."""
    pad = len(TRAY_OLD) - len(_TRAY_NEW_CORE)
    if pad < 0:
        sys.exit("FATAL: tray patch too long by %d bytes" % (-pad))
    lines = _TRAY_NEW_CORE.split(b"\n")
    lines[1] += b" " * pad
    return b"\n".join(lines)


def main(argv):
    flags = [a for a in argv[1:] if a.startswith("--")]
    paths = [a for a in argv[1:] if not a.startswith("--")]
    if len(paths) != 1:
        sys.exit("usage: %s [--tray-toggle] [--notif-ignore] <file>" % argv[0])
    path = paths[0]
    data = open(path, "rb").read()
    orig = len(data)

    # --soft: не умирать при отсутствии паттерна, а предупредить. Нужен
    # live-ebuild'у (viber-9999): апстрим может переписать QML/moc-строки,
    # и сборка каждого нового релиза не должна вставать из-за патча.
    soft = "--soft" in flags
    rc = 0

    if "--tray-toggle" in flags:
        new = tray_new()
        assert len(new) == len(TRAY_OLD), (len(new), len(TRAY_OLD))
        n = data.count(TRAY_OLD)
        if n != 1:
            msg = ("tray pattern occurs %d times (expected 1) — upstream "
                   "изменил QML, патч нужно переписать" % n)
            if soft:
                print("WARN: " + msg)
                rc = 2
            else:
                sys.exit("FATAL: " + msg)
        else:
            data = data.replace(TRAY_OLD, new)
            print("patched: tray toggle (--tray-toggle)")

    if "--notif-ignore" in flags:
        assert len(NOTIF_NEW) == len(NOTIF_OLD)
        n = data.count(NOTIF_OLD)
        if n != 1:
            msg = ("notif pattern occurs %d times (expected 1) — upstream "
                   "изменил moc-строки, патч нужно переписать" % n)
            if soft:
                print("WARN: " + msg)
                rc = 2
            else:
                sys.exit("FATAL: " + msg)
        else:
            data = data.replace(NOTIF_OLD, NOTIF_NEW)
            print("patched: notification click ignored (--notif-ignore)")

    if len(data) != orig:
        sys.exit("FATAL: size changed %d -> %d" % (orig, len(data)))
    open(path, "wb").write(data)
    print("OK: %s (%d bytes, размер не изменён)" % (path, orig))


if __name__ == "__main__":
    main(sys.argv)
