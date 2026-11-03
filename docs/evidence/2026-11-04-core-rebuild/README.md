# 18 кандидатов ARM64 из закреплённых исходников — 4 ноября 2026

## Что готово

Все **18** ядер, для прежних бинарников которых не удалось установить точный
source input, теперь имеют отдельные собранные кандидаты. Оригинальные бинарники,
полный Setup, source binding 58/76 и установленный runtime сохранены. Новые
commits не объявлены исходниками старых файлов.

Для кандидатов собраны **18 source capsules**, **31 Git-дерево** с вложенными
зависимостями, **84 972 412 байт**. Выбрана история upstream на период baseline
27 сентября; AppleWin явно берётся из ветки `libretro`, поскольку `master`
содержит другой frontend. В `candidates.json` закреплены полные commits и
прежние binary hashes; дальнейшая сборка не запрашивает moving HEAD/latest.
Номер версии без совпадения бинарника не признаётся исходным build record.

Все **18** ARM64 ELF собраны и проверены загрузкой под QEMU с `RTLD_NOW`:
25 обязательных libretro symbols, API 1, `retro_get_system_info`. Это запускает
загрузчик библиотеки и getters, но **не** `retro_init`, игру, BIOS или сохранение.
Контроллеры, отрисовка, звук, сохранения и netplay ещё не проверены на этих новых
бинарниках. Старые gameplay результаты автоматически на них не переносятся.

| Core | Новый source commit | Полученная версия API |
| --- | --- | --- |
| `amiarcadia` | `8ca27c925833` | `4.60` |
| `applewin` | `ae584dad0156` | `1.30.21.0` |
| `arduous` | `831b83e67ad4` | `0.1.0 unknown` |
| `b2` | `9793f6a8040c` | `v0.4` |
| `dosbox_pure` | `73e03aa145e0` | `1.0-preview6` |
| `emuscv` | `174071170189` | `0.15.20260921084155` |
| `ep128emu_core` | `6af5d03de220` | `v1.2.13` |
| `gearcoleco` | `3c3b7b6ef047` | `3c3b7b6ef047` |
| `hatari` | `5831f66e05ae` | `2.6.1-devel (Nov  3 2026)` |
| `lowresnx` | `b1ba4da0fd28` | `1.2` |
| `mednafen_pce_fast` | `1c693c630121` | `v1.31.0.0` |
| `minivmac` | `babdf7b53d36` | `b36` |
| `pokemini` | `132111b76343` | `v0.60` |
| `same_cdi` | `ff9bb99a50d5` | `0.287` |
| `uzem` | `d991ee94547c` | `v2.0` |
| `vircon32` | `dd78c5cea1fc` | `2026.2.18` |
| `wasm4` | `9d6c962785cf` | `v1 unknown` |
| `x1` | `3106aa54ffb2` | `0.60` |

`unknown` у arduous/WASM-4 отражает отсутствие `.git` в source archive; точная
ревизия хранится в подписываемом позже наборе материалов, а не угадывается из
этой строки. Gearcoleco получает настоящий commit через upstream `GIT_VERSION`.
Дата Hatari — дата компиляции, не доказательство нового upstream release.

## Исправления сборки и реальные проверки

- Установлен отдельный cross-build container с закреплённым Ubuntu image digest,
  записаны его image IDs и точные пакеты GCC/CMake/зависимостей. Контейнеры сборки
  работали без сети, с read-only root и доступом только к staging. Это не обещание
  bit-identical пересборки из будущих APT repositories: snapshot пока не закреплён.
- AppleWin требует Boost headers и `xxd`; отсутствующие build tools добавлены в
  контейнер. Код эмулятора не менялся.
- Hatari собирается только как `hatari_libretro`: упаковка посторонней manpage
  ломалась на нормализованных timestamps source archive. Для завершения уже
  скомпилированных объектов сверены **745 исходных файлов** с исходным capsule;
  только после совпадения использован build cache. Полная команда core-only
  сборки сохранена в новом рецепте.
- Реальная загрузка выявила отсутствующие явные зависимости: `powf` у WASM-4,
  `log10l` и `udev_device_get_devnode` у Hatari. Link recipes теперь подключают
  `libm`, а для Hatari также `libudev` и строгую проверку unresolved symbols.
  Исправленные файлы повторно прошли загрузку. Старые неудачные кандидаты сохранены.
- DOSBox Pure собирается с явным `UNAMEM=aarch64`; host x86 не выбирает его target.
  [Официальный asset `476963084`](https://github.com/schellingb/dosbox-pure/releases/tag/1.0-preview6) с той же версией `1.0-preview6` имеет другой
  binary hash (`9b2688e4a9e78cd0af77ac8597a87dfc2cf618edaf69ae8a9ace6b6fdc357c88`),
  чем предыдущий `a391d870...`. Он не подменён под видом той же сборки.
- **7 тестов** build/package guards прошли на Windows и Linux: изменённые sources,
  неправильный commit/path, x86 вместо ARM64, сохранение прежней идентичности,
  отказ затирать попытку/архив, нарушенный output hash, отсутствующая ABI проверка
  и неоднозначный выбор попытки. [Linux log](linux-tests.txt).

[Рецепты и воспроизведение](../../../packaging/emulators/core-rebuild/README.md),
[build records](builds.json), [ABI probes](probes-final.json),
[источники](sources-index.json), [toolchain](toolchains.json),
[явный выбор кандидатов](selection.json).

## Самостоятельный комплект

`TrainerOS-Core-Rebuild-CANDIDATE.tar`: **157 890 560 байт**, SHA-256
`824e060eaef1f3bc1946596a6f925936cfc36ddcd45fb9ab6a859eb7ad7c824e`.
**97 вложений** повторно прочитаны: 18 cores, точные исходники и
manifests, build logs/commands, toolchain package inventories, probes, recipes
и notices. Бинарники занимают **72 167 920 байт**. Тяжёлые материалы находятся на
сервере; в Git — код, pinned inputs и [проверяемая опись](bundle.json).
[Контрольные суммы](SHA256SUMS).

Это **candidate kit**, без `runtime-set.json` и автоматической установки.
Пакетировщик требует полный набор, явный выбор одной удачной попытки на core,
совпадающие source/binary hashes и успешный probe именно выбранных байтов.
Все 18 upstream inputs кандидатов известны; полнота licensing/dependency review
по-прежнему не утверждается. Старый реестр из 78 release capsules сохранён,
новые 18 кандидатов находятся в отдельном [source plan](../../../packaging/emulators/core-rebuild/sources.json).

## Следующий результат

Проверить выбранные cores в настоящем частном RetroArch на Flip из отдельного
каталога: загрузка зависимостей в его Flatpak, затем затронутые launch/save/input
маршруты и необходимые multiplayer checks. После этого подготовить новый
runtime generation, сохраняя старый для rollback, и включить проверенные замены
в Setup. Старые неизвестные inputs не надо снова искать по тому же кругу: теперь
для них есть конкретные кандидаты и сохранённые исходники.

Отдельно остаются VirtualJaguar dirty diff, внешние build/source/notices зависимости
Flatpak/AppImage/Python, упаковка моделей и финальный GitHub/OTA выпуск.
Неполные плановые multiplayer-функции не добавлены в условия альфы. В этом проходе
портативки не использовались, runtime generation не менялся, публикации нет.
