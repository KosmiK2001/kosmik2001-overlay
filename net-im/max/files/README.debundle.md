# Qt-debundle для net-im/max (USE="qt_stack_build")

Если пакет net-im/max собран с `USE="qt_stack_build"`, вендорские Qt-библиотеки
в `/opt/max` заменяются на **собранные здесь** из исходников Qt 6.11.0
(контроль происхождения: не чужой CI-бинарь, а наша сборка).

## Что ставится

- `/usr/libexec/max-debundle/qt-debundle.sh` — хелпер (сборка + подложка + откат);
- `/etc/max/qt-stack-build` — маркер включения;
- сами собранные `libQt6{Core,Gui,Network,DBus,Widgets,Xml,Concurrent,OpenGL,XcbQpa,Svg}.so.6`
  в `/opt/max/lib64` вместо вендорских.

## Что происходит при emerge

`pkg_postinst` (единственная фаза без sandbox, работает от root) сам запускает
хелпер: qtbase-6.11.0 собирается ebuild-фазами в `/var/tmp/portage` (~7 мин на
32 ядрах, с ccache быстрее), qtsvg-6.11.0 — через cmake против собранного
qtbase (~1 мин). В систему пакеты не ставятся, системный Qt 6.11.2 не
затрагивается. Повторный emerge с флагом переиспользует готовый image — быстро.

## Управление вручную

```sh
# деплой (пересобрать при необходимости и подложить)
/usr/libexec/max-debundle/qt-debundle.sh deploy --with-svg

# откат на вендорские (из бэкапа /var/lib/max/qt-vendor-backup)
/usr/libexec/max-debundle/qt-debundle.sh --restore

# штатный откат: пересборка без флага
USE="-qt_stack_build" emerge -1 net-im/max
```

## Почему именно 6.11.0

Приватный ABI Qt версионируется по минору (`QtPrivate_6_11_0` vs `6_11_2`):
вендорские Quick/Qml/WebEngine собраны против 6.11.0, поэтому наш qtbase обязан
быть ровно 6.11.0 (в ::gentoo только 6.11.2+ — поэтому пины
`dev-qt/qtbase-6.11.0`/`dev-qt/qtsvg-6.11.0` живут в этом оверлее).

## Ограничения

- Модули Quick/Qml/WebEngine/Multimedia остаются вендорскими (они и так
  бинарно совместимы с нашим qtbase).
- Трей и звонки — ограничения самой сборки max, не зависят от дебандинга.