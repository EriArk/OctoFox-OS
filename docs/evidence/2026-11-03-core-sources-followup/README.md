# Дополнение к исходникам cores — 4 ноября 2026

## Результат

Установлены ещё **8** upstream inputs без замены бинарников: MAME, ScummVM,
Stella, Cemu, TIC-80, FinalBurn Neo, Fuse и Game & Watch. Теперь регистр покрывает
**58 из 76** ядер, **18** остаются неопределёнными. Восемь новых capsules содержат
576 691 443 байта и 41 Git-дерево с повторами;
общий реестр материалов выпуска вырос с 70 до **78** capsules.

Новый `TrainerOS-Core-Sources-03-CANDIDATE.tar` собран на сервере:
**1 866 885 120 байт**, SHA-256 `c58e8b43612a39bc4b1b15c4537094f596dc4dfd7a71aa53950ece5ff9c8d1b0`.
В нём **55** уникальных upstream archives, source manifests, наши handheld
patches/recipes и notices. Все **121 вложение** повторно прочитаны и сверены.
Предыдущие source archives сохранены. Бинарный component archive по-прежнему
`b0bc151b3d9e8cb7b977e45da7eba3e2ba82050f70a000913f6ac684668647c7`; состав и байты всех 76 cores неизменны.

[Проверенная опись](bundle.json), [capsules](capsules.json),
[полная таблица](COVERAGE.md), [метки и бинарные хеши](markers.json),
[контрольные суммы](SHA256SUMS).

## Как установлены ревизии

| Core | Встроенная строка | Upstream commit |
| --- | --- | --- |
| `cemu_libretro.so` | `Cemu 0c11cf8` | [0c11cf8e79ae](https://github.com/WizzardSK/cemu-libretro/commit/0c11cf8e79ae5662456d41458d62d099c232ddcc) |
| `fbneo_libretro.so` | `GITaceeebe` | [aceeebed9e7e](https://github.com/libretro/FBNeo/commit/aceeebed9e7edc8a28652365a064baee9a16e274) |
| `fuse_libretro.so` | `e997e2bc32c888348f862f69f2c53babfedf7791` | [e997e2bc32c8](https://github.com/libretro/fuse-libretro/commit/e997e2bc32c888348f862f69f2c53babfedf7791) |
| `gw_libretro.so` | `dddc9d553f7503f17c3dfd1906bc94c07eff8515` | [dddc9d553f75](https://github.com/libretro/gw-libretro/commit/dddc9d553f7503f17c3dfd1906bc94c07eff8515) |
| `mame_libretro.so` | `0.289 (9069f3934)` | [9069f39340f2](https://github.com/libretro/mame/commit/9069f39340f2d2b1795df8e71bb1d3d0fbc76598) |
| `scummvm_libretro.so` | `fcbce3ae-2026.3.1git` | [fcbce3ae8152](https://github.com/scummvm/scummvm/commit/fcbce3ae815269dacdc309092bc92ccc6d3e13bb) |
| `stella_libretro.so` | ` 36db826` | [36db8267e443](https://github.com/stella-emu/stella/commit/36db8267e443a1ddfe4fabc0a3d42ec2b2332cb4) |
| `tic80_libretro.so` | `1.2.38-dev (ae1195a)` | [ae1195a9d0fb](https://github.com/libretro/TIC-80/commit/ae1195a9d0fbda243bf0ebd861d6876d072a979e) |

У Stella пробел перед хешем значим: версия хранится отдельно, а итоговая строка
собирается во время работы. У ScummVM хеш стоит перед версией; у MAME/TIC-80 —
в скобках. FinalBurn Neo подставляет `GIT`-метку через
`src/burner/libretro/Makefile.common` и использует её в `retro_get_system_info`.
Fuse и Game & Watch генерируют `version.c` с полным `git rev-parse HEAD` через
`Makefile.libretro`; это не случайные ROM-хеши из базы игры.

Поиск строк использовался для выбора кандидатов, а не для автоматического
признания произвольного шестнадцатеричного числа ревизией. Для поиска дополнительно
прочитан машинный код `retro_get_system_info` статическим дизассемблером на сервере;
ядра не загружались и не исполнялись. Capstone 5.0.3/pyelftools 0.32 — изолированные
операторские инструменты, в Setup не добавлены. Описи `.info` не определяют source
revision: они местами устарели.

Полные commits разрешены через официальный GitHub API; collector получил именно
эти Git-деревья и закреплённые gitlinks. Существующий `core_sources.py` проверил
размер/SHA-256/ARM64 каждого core, наличие выбранной NUL-terminated строки,
соответствие source commit, capsule hash и полный состав итогового архива.
Пройдены **9 CoreSourceTests + 12 SourceCapsuleTests** на Windows; настоящий
комплект собран и независимо прочитан упаковщиком на Linux. Исходники упаковщика
не менялись; проверка новых данных не выдается за новое игровое тестирование.

## Остаток и следующий шаг

Точная ревизия пока неизвестна у: `amiarcadia`, `applewin`, `arduous`, `b2`, `dosbox_pure`, `emuscv`, `ep128emu_core`, `gearcoleco`, `hatari`, `lowresnx`, `mednafen_pce_fast`, `minivmac`, `pokemini`, `same_cdi`, `uzem`, `vircon32`, `wasm4`, `x1`.

Для этих 18 следующий маршрут — восстановить сохранённые build/download records
или проверить точный оригинальный upstream asset; при отсутствии такого пути
подготовить отдельную сборку с известными исходниками и проверкой затронутого
runtime до замены. Текущий `buildbot/latest` — изменяемый каталог, он не выбран
как воспроизводимая замена старых сборок. Не подставлять tag только по версии.

Условия распространения проверяются по лицензии каждого компонента: unknown
source identity не означает одинаковый запрет для permissive, copyleft и
non-commercial кода. Полный binary build/dependency review и неизвестный
VirtualJaguar dirty diff остаются открыты. `redistributionReviewed` и
`completeCorrespondingSourceReviewed` остаются `false`.

Далее сохраняются Flatpak/AppImage/Python native dependencies, incorporated-
упаковка аватара и GitHub/OTA. Неполные функции мультиплеера не становятся новым
условием альфы. Flip/Odin, Software/runtime media, публикация и OTA feed в этом
проходе не менялись. [Предыдущая стадия 50/76](../2026-11-03-core-sources/README.md)
сохранена как историческое доказательство.
