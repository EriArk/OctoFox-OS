# Матрица мультиплеерных механизмов по платформам

**Срез кода:** `e4e16a713e3496042d4284f3f8ec7b337f98fc80`; 3 ноября 2026. Статусы: `PAIR` — в историческом отчёте реальные независимые игровые действия двух устройств; `NATIVE` — сетевые/системные процессы, не завершённый матч; `LIMITED` — один узкий профиль/запуск; `SETUP` — настроено/есть код, но матч не подтверждён; `TARGET` — будущее. **Ни один статус не является полной сертификацией всей платформы или тестом сегодняшней alpha-сборки.**

| Платформа / семейство | Конкретный механизм | Доказательство и статус | Ограничение |
| --- | --- | --- | --- |
| NES / FDS | RetroArch FCEUmm shared NetPlay; другие cores по профилю | **PAIR:** NES Pong P1/P2 и повторный вход, один router/внешний relay | FDS BIOS и другие игры не сертифицированы |
| SNES | RetroArch Snes9x, отдельные pads | **PAIR:** Contra III US, самостоятельные движения/бомбы и Rejoin | Multitap, 3–4 клиента и WAN не приняты |
| SG-1000 / Master System / Mega Drive / Sega CD / 32X | Genesis Plus GX и PicoDrive shared NetPlay | **PAIR:** Streets of Rage 2; **NATIVE** Chaotix PicoDrive late join | Игры/ядра и формат BIOS отдельно |
| PC Engine / PC Engine CD / SuperGrafx / Atari 2600 | Beetle PCE Fast, SuperGrafx, Stella | **NATIVE:** Reflectron / Beetle PCE rejoin, core metadata/tests | SuperGrafx тестировался с PCE-контентом; отдельные игры/Stella не приняты |
| FBNeo / Neo Geo / аркады MAME | RetroArch shared console | **NATIVE:** Metal Slug 3, Battle Circuit native rejoin; есть старый arcade netplay | Не все ромсеты/BIOS; MAME live join не подтверждён |
| Neo Geo CD | Patched NeoCD shared two pads | **NATIVE:** исправленное ядро и профиль установлены Flip/Odin 02.11 | Нет конкретного завершённого retail парного матча этого прохода |
| Game Boy / Color | DoubleCherryGB, SameBoy Link; разные машины/сейвы | **PAIR/LIMITED:** обмены и связанный gameplay в старых проверках | RTC, mapper, game-specific Save; не RetroArch shared pads |
| Game Boy Advance | gpSP RFU, mGBA link/splitscreen | **PAIR:** Mario Golf Advance Tour и protected save return | Не все wireless/RFU игры; 4 логических машины ≠ 4 портативки |
| Neo Geo Pocket/Color | NgpCraft MirrorSession, 2 собственные машины | **NATIVE:** ARM 300 кадров, live ICE/DTLS, Flip X11 window | Нет подтверждённого игрового матча с двумя физическими пользователями |
| Nintendo 64 | Native RMG/Mupen64Plus netplay | **PAIR/LIMITED:** Mario Kart 64 relay и Home/Exit | Плагины, большая группа, WAN |
| PlayStation 1 | PCSX ReARMed shared RetroArch netplay | **NATIVE:** CTR US Rejoin, конкретные 2P профили | **DuckStation — solo**, не этот сетевой путь; стабильность и диски по версии |
| PlayStation 2 | ARMSX2 DEV9 native LAN + private transport | **LIMITED:** Battlefront II: владелец подтвердил LAN; ранее peer joined | 56 LAN названий/164 serial — каталог, не 56 PASS; утилита PS2 теряет ввод и артефакты |
| PSP | PPSSPP Ad Hoc / public relay и host-relay 2P | **PAIR:** Ridge Racer, Virtua Tennis, Killzone, Shin Budokai, Tekken, Lumines | Sonic Rivals 2 **FAILED**; все игры/ISP и CSO/PBP edge не подтверждены |
| Dreamcast | Flycast Dojo GGPO | **PAIR/LIMITED:** Soul Calibur paired | Native online game-server отдельно |
| Dreamcast native Online | Flycast Online, native VMU/flash | **SETUP:** ChuChu Rocket boot and save; **NO** real Online match | Серверы, service login, разные сети |
| Naomi/Naomi 2/Atomiswave | Flycast Dojo GGPO, отдельно cabinet LAN | **NATIVE:** Dolphin Blue 2 peers Session Start | Session Start ≠ игровой матч; известны повреждённые ZIP |
| GameCube/Wii | Dolphin native NetPlay | **PAIR:** Melee US v1.01, NSMB Wii historical | Wiimote, 4 клиентов, WAN; BBA/Native Online — отдельные пути |
| GameCube BBA | Dolphin BBA / отдельные машины | **NATIVE:** bridge, пакеты/launcher | Double Dash/Kirby/1080 в списке не означают протестированную игру |
| Nintendo DS Wireless | Patched melonDS | **PAIR:** Mario Kart DS / отдельные wireless machines | Не WFC/DSi, не полная handheld coverage |
| Nintendo DS WFC | melonDS WFC / external game-server | **SETUP:** source/identity route | Не принят независимый WFC online match |
| Nintendo 3DS wireless | Azahar, native wireless room | **PAIR:** Minicraft3DS, protected saves | Retail updates/DLC, 4P/WAN не подтверждены |
| Nintendo 3DS Online | Azahar + supported external service | **SETUP:** собственный online-account и helper | Не все коммерческие игры/аккаунты/servers |
| Wii native Online | Dolphin + external Online service | **SETUP:** guided setup, separate from Dolphin NetPlay | Онлайн-матч не доказан |
| Wii U | Cemu native online + personal console/account data | **SETUP/TARGET:** исходники/настройка; нет общего допущенного multiplayer | Нет подготовленной чистой учётки/пары; не обещать |
| Original Xbox | xemu System Link | **NATIVE:** 2–4 independent Xbox console transport installed Flip/Odin | System Link выбирают внутри игры; Xbox Live не реализован; нет каталога проверенных title matches |
| Sega Model 3 | Supermodel native CNetBoardLink | **NATIVE:** 2/3/4 native processes, real packet round-trip | Не 4 реальные игровые кабинета/матча |
| Doom | Odamex native server на устройстве хозяина | **NATIVE:** 2/4 clients; installed Flip 01.11 | Odin не обновлялся в этом проходе; пользовательский WAN/title и любые GZDoom mods не приняты |
| PlayStation Vita | Vita3K, точный vitaQuake LAN | **PAIR:** Flip/Odin два игрока, движение/стрельба/патроны | Не commercial Vita Ad Hoc/PSN |
| Xbox 360 / PS3 / Switch | Экспериментальные или отсутствующие netplay механизмы | **TARGET** | Xbox360/PS3 исключены из подбора, Switch solo ≠ Online |
| PC games native LAN | План #251, отдельные PC/Proton runtimes | **TARGET** | Импорт PC игры не создаёт автоматический LAN; Remote Play иной режим |

### Откуда берётся допуск

[RuntimeMultiplayer / candidate/profile scan](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/adventure/RuntimeMultiplayer.cpp) подхватывает только **точные** допустимые режимы и проверенные локальные runtime/helpers; нерегистрированная игра не появляется как готовая Online из-за одной иконки или метаданных «2 игрока». В shared-console пути одинаковый runtime binary SHA участников **не всегда обязателен** (ARM/x86 могут отличаться), но `core/profile/mode/settings/content/firmware` и локальная установленная integrity обязаны быть совместимыми. Не считать отсутствие жёсткого SHA-сравнения доказательством cross-architecture gameplay.

Источники: [реализация и границы](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/EMULATOR_MULTIPLAYER_MATRIX.md), [релизная матрица 03.11](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_RELEASE_MATRIX_RU.md), [архитектурный допуск](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/NETPLAY_RELAY_SELECTION.md), [форматы, не игры](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_CONTENT_FORMATS.md), [Model3](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/evidence/model3-link-20261101/README.md), [NGPC](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/evidence/ngpc-link-20261102/README.md), [Odamex](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/emulators/odamex.md), [xemu](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/emulators/xemu.md), [PS2](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/emulators/armsx2-lan.md).

**Реестр кандидатов владельца — не матрица успешных матчей:** исходно 321/26 семейств, после исключения Xbox360/PS3 — 314/24 семейств, позже добавлены пять PSP; фактический импорт образов и количества метаданных недостаточны. [подборка владельца](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_SELECTION_DELIVERY.md). Подтверждённые игры отдельно: [MULTIPLAYER_TESTED_GAMES.md](MULTIPLAYER_TESTED_GAMES.md).
