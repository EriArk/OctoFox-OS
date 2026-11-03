# Материалы исходников и лицензий — 3 ноября 2026

- [Единый архив](source-bundle.json): 2 024 867 840 байт, все 48 вложений повторно
  прочитаны/проверены. [SHA256SUMS](SHA256SUMS), [точный сборочный скрипт](assemble.py).
  Runtime recipes включают исходники/патчи из `369e4087`; модельные файлы аватара
  в этот recipes archive не копировались. Комплект пока не публиковался.
- [22 source capsules](source-capsules.json): закреплённые commit/tree, SHA-256,
  notices, вложенные Git-зависимости и отдельный LFS-объект. 286 деревьев,
  247 уникальных repository/commit, 1 965 733 612 байт сжатых архивов.
- [Python source/notices supplement](python-notices-bundle.json): 38 sdist,
  305 файлов, 56 612 060 байт. Копия на сервере повторно сверена по SHA-256.
- [AppImage identities](appimage-identities.json): реальные хеши семи пакетов,
  лицензии из metadata и кандидаты Git commit из ELF. Строка commit сама по себе
  не доказывает точный build recipe или права распространения.
- [Flatpak inputs](flatpak-source-inputs.json): manifest точных установленных
  commits. Это список входов, не скачанные исходники платформ.
- [17 Linux-проверок](source-tests.log): gitlink, export-ignore/subst, LFS hash/size,
  внешняя source-ссылка без её чтения, отказ для moving ref/URL/path, повреждённые
  материалы, сохранность существующего/частичного output. Те же 17 проверок прошли
  на Windows; новых проверок приложения/игр не выполнялось.

Сборщик запускает Git/read-only архиваторы; эмуляторы и upstream build не запускались.
DwarFS для чтения AppImage — официальный v0.15.8, сверенный x86_64 archive SHA-256
`f5eb34c3e2ac1bfcbe66e15b8a66da20897049b22867d2c193bffedf25cc08ae`.
Тулза проверки не входит в установщик. На Flip не было смены сессии/сборки/runtime;
Odin не использовался. Нет новой физической, игровой или сетевой приёмки.

[Состав, команды и незакрытые пункты](../../RELEASE_SOURCE_BUNDLE_RU.md).
