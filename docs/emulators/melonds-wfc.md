# DS WFC — native internet mode

## Состояние — 2 ноября 2026

Реализован отдельный `runtime.melonds.wfc.v1`: обычное Online Lobby → выбор
Nintendo WFC → готовность участников → явный Start хозяина → WFC-меню самой
игры. У каждого свой DS, экран, ввод и постоянный WFC-прогресс. Это подготовка
и совместный запуск; TrainerOS не обещает автоматически найти комнату или
соперника внутри игры. Повторное подключение выполняет игрок в игре.

Портативки в этом проходе не подключались и не обновлялись. Локальная Windows
сборка и проверки не заменяют поставку ARM64. Обычный установленный DS wireless
сохранён: его два связанных DS и собственный механизм синхронизации не меняются.
Четыре места нового WFC-лобби — предел совместного запуска, не утверждение о
четырёх участниках любого игрового режима или о готовности четырёх DS wireless.

## Выбор готовой технологии

- [melonDS DS](https://github.com/JesseTG/melonds-ds), release 1.4.0,
  `f394adbacb5722ee97c1b37c8064da9a25818310`. Содержит готовые Wi-Fi, SLIRP,
  генерируемую firmware и FreeBIOS; не требуется пользовательский дамп BIOS.
- Подлежащий melonDS закреплён на `16f127dbb587a73371827ce79689c5d237c4b59b`;
  остальные полные ревизии — [dependencies.json](../../packaging/emulators/melonds-wfc/dependencies.json).
- [Контракт Libretro](https://docs.libretro.com/library/melonds_ds/) описывает
  native WFC и автоматическую AP. [Kaeru WFC](https://kaeru.world/projects/wfc)
  предоставляет DNS `178.62.43.212` и подключение неизменённых игр к замещающей
  инфраструктуре. Доступность и поддержка конкретной игры зависят от этих сервисов.
- Сравнен существующий standalone melonDS 1.1: wireless остаётся на нём, а для
  WFC выбран готовый libretro frontend с автоматической AP/DNS и SRAM-контрактом.
  Новая эмуляция протокола, свой WFC-сервер, VPN, TURN или relay не добавляются.

Сеть — `indirect`, DNS задан явно; пользователь не вводит адреса и не открывает
системное меню DS ради подготовки сети. Игровой поиск/регистрация/друзья зависят
от самой игры. Это не обещание обхода любого NAT или cross-edition совместимости.

## Небольшой upstream patch

[0001-register-console-mac.patch](../../packaging/emulators/melonds-wfc/0001-register-console-mac.patch)
подключает уже существующий `ParseMacAddressFile` к обнаружению core options.
В исходной версии список MAC оставался пустым: frontend отвергал заданный адрес
и возвращал общий firmware default. Патч только регистрирует найденные адреса;
не меняет сетевой протокол или игровые пакеты. Реальное ядро до патча показало
`00:09:BF:11:22:33`, после — заданный приватный адрес при обоих запусках.

## Интеграция и сохранения

Владельцы: S03 — `MelonDsWfc`, установленный RetroArch и pinned core; S06 —
прежние Lobby/Ready/Start и отдельная WFC-строка; S07 — прежние приглашения и
сигнал готовности, без пересылки игровых кадров; S08 — общий protected-save return.
Home/выход и ввод обслуживает существующий RetroArch/process маршрут.

- Обнаружение проверяет bundle manifest, SHA-256 ядра, исполняемый frontend и
  распакованный NDS/SRL. ZIP/7z допускают один картридж. Unit code 0 и 2 работают
  в DS-режиме; DSi-only 3 исключён. Списка проверенных названий или ROM-хешей нет.
  Отсутствие у игры WFC нельзя установить по расширению: доступный механизм не
  является сертификатом игрового сервиса. `players=1` означает локальный экран,
  поэтому не скрывает независимые WFC-машины.
- WFC доступен только в Online. Это отдельная строка от обычного DS wireless;
  ни Nearby, ни настройки RetroArch relay ему не предлагаются.
- Каждый локальный профиль и содержимое ROM получают стабильный собственный
  MAC. Он не зависит от имени/папки ROM, имени в чате, peer или сетевого адреса.
  Процесс получает приватные system/save/state каталоги; global core options,
  cheats, autosave states, runahead и RetroArch shared NetPlay не наследуются.
- Отдельный WFC-прогресс показан на карточке. Обычный standalone SAV/firmware
  не импортируется и не перезаписывается. SRAM и 2304 байта WFC-настроек хранятся
  одним непрозрачным envelope под `<backupRoot>/ds-wfc/<owner>/<content>/progress.bin`. Собственный WFC ID не расходится с SRAM
  при атомарном возврате. Данные другого игрока не передаются.
- Действуют собственник/контекст/ревизия, backup, readback, блокировка повторного
  запуска и отказ при внешнем изменении. Повреждённый envelope, потеря ранее
  существовавшего SRAM/WFC, crash и принудительный stop не заменяют предыдущий
  прогресс; приватная session-копия остаётся для восстановления.
- Потеря лобби не убивает уже запущенный native Online процесс. Возвращение в
  лобби само не запускает игру; сигнал готовности привязан к режиму и месту.

## Воспроизводимая сборка и поставка

Нужны Python 3, Git, CMake, Ninja, C/C++20 toolchain и зависимости upstream.
На Armada source/build/dependency caches держать на microSD. Пример для Linux:

```sh
git clone https://github.com/JesseTG/melonds-ds.git melonds-wfc-src
git -C melonds-wfc-src checkout f394adbacb5722ee97c1b37c8064da9a25818310
python3 packaging/emulators/melonds-wfc/build.py melonds-wfc-src melonds-wfc-build melonds-wfc-stage
python3 -m venv melonds-wfc-check
melonds-wfc-check/bin/pip install libretro.py==0.12.0
melonds-wfc-check/bin/python packaging/emulators/melonds-wfc/check.py melonds-wfc-stage/melondsds_libretro.so
```

Recipe проверяет source/зависимости, применяет только записанный patch и создаёт
новый staging bundle с manifest и полными upstream notices. OpenGL выключен,
выбран software renderer/JIT; это консервативный базовый режим, не замер ARM64
производительности. Обычный графический backend RetroArch сохраняется.
Для Windows нужны `--cmake-arg=-DCMAKE_C_COMPILER=...` и CXX compiler при
нестандартном PATH; `check.py --dll-directory ...` задаёт каталог DLL toolchain.

Поставка после освобождения устройств: проверить host dependencies и отсутствие
игры, сохранить старый bundle, разместить staging в
`$XDG_DATA_HOME/TrainerOS/emulators/melonds-wfc` (обычно `~/.local/share/...`),
поставить совместимую оболочку штатным способом. Базовый RetroArch, solo melonDS,
профили и saves не заменять. Установка не выполнена этим документом/recipe.

Обновление: сверить upstream WFC/storage/options и service DNS, закрепить все
ревизии, перепроверить необходимость MAC patch, изменить settings revision при
несовместимом контракте, прогнать native check и защиту progress. Не переписывать
старое хранилище новой схемой молча. Откат: при закрытой игре вернуть прежний bundle
и shell; `progress.bin`, backups и recovery sessions оставить без изменений.
Сохранять соответствующие исходники, patch и third-party notices с распространяемым
бинарным пакетом; пользовательские ROM/BIOS/saves в пакет не включать.

## Проверки и границы

Локально собраны настоящие melonDS DS/core и TrainerOS C++ owners. Native probe
исполняет 600 кадров собственного минимального ROM в двух отдельных процессах:
FreeBIOS/firmware, SLIRP init, автоматическая `melonAP`, DNS, CRC, постоянный MAC,
повторное чтение синтетического WFC ID и неизменность ROM. Он не регистрирует
аккаунт сервиса и не выдаётся за WFC-матч. C++ проверки покрывают архивы/DSi
границы, разные owner states, атомарный возврат, отказ при повреждении/подмене,
крахе/потере save, раздельные режимы в picker и сохранение игры при потере лобби.

Первоначальные результаты — [evidence](../evidence/ds-wfc-20261102/README.md).
В последующем [проходе подготовки](../evidence/ds-groups-preparation-20261102/README.md)
собран ARM64-пакет и повторён native probe под QEMU: 600 кадров, собственный WFC ID
сохраняется между процессами. Toolchain явно задаёт AArch64 для C/C++ и ASM;
`check.py --worker-python` принимает QEMU wrapper для целевого Python. Поставка и
игровой обмен через сервис не выполнены. R043 остаётся частичным; отдельные
DS Wireless 2–4 также подготовлены в source/ARM64, но ещё не установлены.
