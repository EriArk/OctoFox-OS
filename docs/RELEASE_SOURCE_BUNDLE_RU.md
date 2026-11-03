# Исходники и лицензии полного установщика

## Новое дополнение: Azahar, melonDS, RPCS3 и транспорт Setup

Собраны ещё три exact-source capsules с вложенными Git-деревьями, всего **27**;
их совокупный размер теперь **2 754 693 176 байт**. Новое дополнение упаковано
отдельно, старые архивы сохранены. Embedded identity фактических AppImage
подтверждена чтением ELF и разрешением upstream commit. Это не доказательство
полноты packaging dependencies готовых бинарников.

Software-source точного `2a6c9c9b` теперь подготовлен без 121 файла геометрии
аватара: **343 808 402 байта**, 3369 остальных файлов и опись исключений. Оригинальный
Git archive сохранён. В full Setup заменён только этот source archive; остальные
82 файла неизменны. Подготовлены части по 1 GiB и маленький Download kit с докачкой.
[Артефакты и проверки](evidence/2026-11-03-release-delivery/README.md).

Оставшаяся очередь: точные source/build зависимости готовых libretro cores,
Eden, Flatpak runtime/platform, AppImage и native-библиотек wheels; incorporated
упаковка avatar assets; финальная публикация GitHub/OTA. Eden embedded commit
`da42070c4ad25840c9ee25344bde9d0a8584f5a9` пока не собран; другой tag 0.2.1 не
используется как его замена. Новых обещаний PS3/Switch multiplayer это не добавляет.

**Последующее решение владельца:** разрешено автоматическое получение точного
официального runtime с локальной настройкой. Для DuckStation реализован этот путь:
его бинарника нет в новом hybrid media, оригинальный asset скачивается во время
Setup с проверкой хеша. Предыдущий вопрос о варианте поставки ниже заменён этим
решением. Это не разрешение перепаковывать/публиковать изменённый DuckStation и не
завершение остальных source/license условий.
[Новый путь и проверки](evidence/2026-11-03-hybrid-runtime/README.md).

## Дополнение: Cemu/ARMSX2 и DuckStation, 3 ноября

Теперь собраны **24 source capsules**: 2 126 557 701 байт, 297 Git-деревьев с
повторами. Новые Cemu/ARMSX2 привязаны к embedded identity фактических AppImage.
[Дополнение 160 849 920 байт](evidence/2026-11-03-appimage-provenance/README.md)
собрано отдельно; шесть вложений повторно прочитаны и сверены. Предыдущий единый
архив из 22 capsules ниже сохранён и не переписывался.

Cemu: встроенная ревизия `cee557d46d63e3407dc3bbda6480c0c674e8bb80` подтверждена;
неизвестными остаются точный packaging build и его внешние библиотеки.
DuckStation: LICENSE/README **нашего** commit `dd4a0eb...` подтверждают CC-BY-NC-ND
и позицию автора о преднастроенных пакетах как модификациях. Владелец выбирает
отдельно подключаемый DuckStation либо включение после отдельного разрешения.
До выбора состав кандидата не меняется; публичного разрешения для него нет.

## Результат 3 ноября 2026

Для текущего автономного кандидата подготовлены **22 архива закреплённых исходников**:
1 965 733 612 байт, 286 деревьев Git с учётом вложенных зависимостей, 247 уникальных
пар repository/commit. Включены 14 native-компонентов из fullbundle recipe,
сервер RMG, четыре handheld-core input, PPSSPP, отдельный libchdr и закреплённый
aemu_postoffice. Это число архивов, не заявление о полной готовности 22 эмуляторов.

В Azahar включён настоящий LFS-файл Teakra размером 357 257 824 байта; SHA-256
сверен с закреплённым указателем. Ссылка EDK2 на `/opt/X11/include` сохранена как
метаданные исходного дерева, без чтения файлов этой системы. Внешние ссылки
перечисляются отдельно для проверки при распаковке; сборщик не распаковывает
исходники в рабочую систему и не запускает upstream build/hooks.

Дополнительно собран `TrainerOS-Python-Notices-CANDIDATE.tar.gz`: 56 612 060 байт,
305 файлов. Он содержит 38 точных Python sdist, METADATA/лицензии из фактических
wheels, найденные notices/patches из native-компонентов и дополнительный текст
LGPL для iterable-io. Входные sdist, wheels и component archives сверяются до
упаковки; несовпадение или повторное имя отвергаются. Существующий/частичный
output не затирается.

Материалы находятся в отдельном серверном staging. Архивы не добавлены в Git;
в репозитории сохраняются рецепты и [проверяемая опись](evidence/2026-11-03-release-sources/README.md).
Единый `TrainerOS-Sources-CANDIDATE.tar` собран: **2 024 867 840 байт**, 48 вложений,
включая 22 upstream-архива, их описи, Python/source/notices и наши runtime recipes
из `369e4087`. Все вложения повторно прочитаны и сверены по SHA-256.
Это отдельный комплект для source review; он не заменяет бинарный установщик
и не объявлен полным Corresponding Source всех компонентов.
Работа не меняла установленную оболочку, сессию, эмуляторы, игры или профили.
С Flip читались только файлы поставки; сбор исходников выполнен на сервере.

## Команды оператора

`source_capsule.py` проверяет полный commit, рекурсивно сопоставляет gitlinks с
`.gitmodules`, сохраняет лицензии даже при upstream `export-ignore`, проверяет
LFS по размеру/хешу и пишет опись. Поддерживается явный HTTPS allowlist;
moving refs и произвольные URL не принимаются.

```sh
python3 packaging/software/source_capsule.py packaging/emulators/release-sources.json \
  --output SOURCE_OUTPUT --cache SOURCE_CACHE
python3 packaging/software/source_materials.py \
  --media VERIFIED_RUNTIME_MEDIA --sources VERIFIED_PYTHON_SDISTS \
  --source-index python-release-sources.json --supplement packaging/licenses \
  --output TrainerOS-Python-Notices-CANDIDATE.tar.gz
```

Наши патчи, добавляемые файлы и recipes находятся в `packaging/emulators`,
`tools/ppsspp-relay`, `tools/ppsspp-content` и остальных maintenance-документах.
Upstream-архив без них не считается готовым исходным комплектом изменённого
бинарника. Воспроизведение toolchain и полное соответствие бинарнику — отдельные
проверки, не следствие успешного скачивания.

## Что ещё требуется до публичного полного пакета

| Область | Подтверждено | Следующий конкретный шаг |
| --- | --- | --- |
| Native-сборки | Закреплённые Git-зависимости, наши recipes/patches | Закрыть внешние build/runtime dependencies и соответствие каждому бинарнику |
| 76 RetroArch cores | Хеши файлов; отдельные source inputs handheld/netplay | Полное соответствие остальных готовых ядер точным source/build recipes |
| 12 Flatpak refs | Manifest inputs точных установленных commits | Собрать исходники платформ/модулей; base manifest PPSSPP не заменяет наш patched build manifest |
| 7 AppImage | Хеши и embedded metadata без запуска | Exact source и зависимости каждого пакета; у Cemu embedded upstream revision подтверждена, packaging/dependencies ещё нет |
| DuckStation | LICENSE/README точного commit подтверждены; автор относит преднастроенные пакеты к модификациям | Прямая загрузка неизменённого upstream asset реализована; завершить установку hybrid Setup и сохранить запрет перепакованной публичной поставки |
| Python native dependencies | Все 38 sdist и доступные notices | Исходники нативных библиотек внутри wheels ещё не признаны полными |
| Две причёски CGTrader | Происхождение и условия зарегистрированы | Incorporated runtime delivery и исключение самостоятельной раздачи моделей из source archive; оригиналы сохранены |

[LICENSE/README точной версии DuckStation](evidence/2026-11-03-appimage-provenance/README.md)
уточняют условия конкретной сборки; текущий настроенный набор ещё не допущен к
публичной поставке. Это не утверждение, что любое включение запрещено. [Условия CGTrader, 21A.3/21B](https://www.cgtrader.com/pages/terms-and-conditions)
требуют мер против извлечения и отличают incorporated use от самостоятельной раздачи.
Сбор материалов не выставляет `redistributionReviewed=true`.

Публичные assets/feed не опубликованы; полный кандидат 08 не заменён новым
runtime-набором. Ни одна платформа не удалена ради прохождения этой проверки.
