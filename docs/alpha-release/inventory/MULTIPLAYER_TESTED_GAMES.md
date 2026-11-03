# Реальные игровые проверки — отдельные от проверки сетевого механизма

**Дата аудита:** 2026-11-03. Информация только из ранее записанных результатов; **сейчас никаких матчей не запускалось**. `GAMEPLAY` = наблюдались **действия обоих участников в одной игре**. `SESSION` = network/Session Start без законченного игрового наблюдения. `BOOT` = игра стартует. `FAILED` = воспроизводимая проблема. **WAN distinct ISP не подтверждён** для перечисленных исторических paired routes, если явно не доказано обратное.

## Подтверждённые в указанных сценариях парные игры

| Игра / издание | Механизм | Проверенный результат | Дата и граница |
| --- | --- | --- | --- |
| NES Pong | NES FCEUmm RetroArch | Flip P1/Odin P2, независимый ввод и игровой счёт, внешнее relay, guest rejoin при неизменном host PID; во время игры существующий голосовой звонок продолжался | 04.10, **один домашний router**, synthetic voice, не separate WAN |
| Contra III US | SNES Snes9x | В меню 2 PLAYERS, независимые движения, использование bombs и guest rejoin на том же уровне/host PID | 04.10, внешний relay и один router |
| Streets of Rage 2 USA | Genesis Plus GX | Flip Axel/Odin Skate, независимые передвижения/пауза, явный re-invite и та же стадия после 12-сек loss | 04.10, общий router; не seamless autorecovery |
| Super Smash Bros. Melee US v1.01 | Dolphin GameCube | Настоящий P1/P2 на двух портативках, room/invite, gameplay и штатный Home/Exit | 03.10, Nearby и Online friend с общей LAN |
| New Super Mario Bros. Wii | Dolphin Wii NetPlay | Исторический парный игровой сценарий и управление/выход | Октябрь, более широкая поддержка/4P не принята |
| Mario Kart DS | melonDS Wireless | Реальный paired wireless/gameplay, own saves/Home | Октябрь, не WFC |
| Minicraft3DS | Azahar local wireless | Проверенный homebrew парный запуск/игра/сохранения | Октябрь, не retail native online |
| Soul Calibur | Dreamcast Flycast Dojo | Пара Nearby/public relay, игровой ввод, Home/Exit | Октябрь, не native Dreamcast server Online |
| Mario Golf Advance Tour USA | GBA RFU | Свои linked screens, независимые действия и protected save return | Октябрь, не все RFU и не 4 физических игроков |
| vitaQuake (exact rebuilt EBOOT) | Vita3K native LAN | Flip/Odin joined 1/2, в одном уровне раздельные движения/выстрелы (25→23 и 25→24 патронов) | 12.10; не Vita commercial Ad Hoc |
| Ridge Racer US **ULUS10001** | PSP PPSSPP | Race Seaside Route 765, оба двигаются/видят соперника; отдельный host-relay test | 24.10: короткая игровая проверка, без полного круга; host relay не полный Fluxer Lobby |
| Virtua Tennis: World Tour US **ULUS10037** | PPSSPP Ad Hoc | Singles exhibition, подача/очки/общий счёт, второй матч Paris→New York без restart | 24.10 |
| Killzone: Liberation US **UCUS98646** | PPSSPP | Trenches Deathmatch, движение, выстрелы, урон, host продолжил после guest Exit | 24.10 |
| Dragon Ball Z: Shin Budokai US **ULUS10081** | PPSSPP | Выбор персонажей и матч Mountains, атаки, здоровье; после истёкшего invite повтор прошёл | 24.10, **не Another Road** |
| Tekken 6 US **ULUS10466** | PPSSPP | Реальный полный бой и новый матч после возвращения relay | 23.10, **причина старых обрывов и реванш не приняты** |
| Lumines: Puzzle Fusion US | PPSSPP 1.20.4 | VS2, независимый ввод и завершение короткого раунда | 03.10, старая сборка/профиль |
| Mario Kart 64 | RMG N64 | Исторический paired netplay через выбранное relay, Home/Exit | Проверить конкретную игру/версию при новой финальной сборке |

### Корректные источники реальных наблюдений

[проверенная выборка PSP/PS2/Arcade](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_TESTED_GAMES.md), [NES/SNES/MD/Dolphin](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/EMULATOR_MULTIPLAYER.md), [партия и общий звонок](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/GAME_PARTIES.md), [GB/GBA](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/HANDHELD_MULTIPLAYER.md), [семейства](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/EMULATOR_MULTIPLAYER_MATRIX.md), [Vita](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/emulators/vita3k.md), [PPSSPP](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/emulators/ppsspp.md).

## Не выдавать за полноценный матч

| Игра / профиль | Что получилось | Вердикт |
| --- | --- | --- |
| PS2 **Star Wars Battlefront II US SLUS-21240** | 24.10 `peer 2 joined`; владелец 25.10 подтвердил, что LAN после настройки работает | **LIMITED**, утилита Network Configuration теряет ввод/показывает графические искажения; полный Lobby/тип сети не записан. **Отложено владельцем** |
| Atomiswave **Dolphin Blue** | Два участника Flycast Dojo `running` / `Session Start` | **SESSION**, не реальный gameplay-result |
| Dreamcast **ChuChu Rocket! MK-51049** | Native Online build обнаружил образ, boot, Home/Exit, VMU/flash | **BOOT**, **НЕ** совместная Online игра |
| NGPC NgpCraft | Реальные mirror-processes / 300 кадров / ICE-DTLS и SDL/X11 | **NATIVE TEST**, без розничного multiplayer матча |
| Model 3 Supermodel | 2–4 native CNetServer/CNetBoardLink процессы реально передали пакеты | **NATIVE TEST**, не 4 пользователя/кабинета |
| Doom Odamex | Native 2/4-client тесты и установленный Flip bundle | **NATIVE TEST**, не принято WAN |
| Xbox xemu System Link | Native bridge/пакеты/установка интеграции | **CODE/NATIVE**, нет удостоверенного title-specific матча |
| PS1 **CTR**, NeoGeo **Metal Slug 3**, 32X **Chaotix**, PCE **Reflectron**, FBNeo **Battle Circuit** | Native late join/exit/rejoin, host PID сохраняется, ограниченное отсутствие desync | **NATIVE REJOIN**; это не полная общеигровая/публичная WAN приёмка |
| Remote Play NES Pong | Один host game, реальный гостевой video/input/возврат P2 без ROM | **REMOTE 2P**, не NetPlay и не 3–4 одновременно |
| Go Live NES Pong | Кадры процесса Flip получены в Qt VideoSink Odin + synthetic sound | **STREAM**, у зрителя нет управления |

Источники: [late join](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY_LIVE_JOIN.md), [NGPC](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/evidence/ngpc-link-20261102/README.md), [Model3](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/evidence/model3-link-20261101/README.md), [Doom](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/emulators/odamex.md), [remote guest](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/REMOTE_PLAY_LOBBY.md), [Watch](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY_MEDIA.md).

## Подтверждённые проблемы

| Игра | Симптом | Статус для альфы |
| --- | --- | --- |
| **Sonic Rivals 2 US ULUS10323** | PPSSPP поиск/вход работает, но переход в гонку нестабилен при Standard и host relay; два успеха не отменяют 3 отказа | **FAILED / UNRELIABLE**; пользователь 24.10 приостановил работу; не описывать как проверенно совместимую |
| **Tekken 6** | Старые обрывы несмотря на полный бой и проверенный возврат | **GAMEPLAY с оговоркой**, причина всех обрывов не закрыта |
| **Battlefront II PS2** | Нет ввода и графические ошибки в конфигураторе сети | **KNOWN ISSUE**, пользователь просил отложить |
| **Пять Atomiswave ZIP** | `kofxi.zip`, `kov7sprt.zip`, `mslug6.zip`, `rumblef2.zip`, `samsptk.zip` не читаются | **Ошибка конкретных файлов**, не доказательство неподдержки игр |
| **Remote Play 3–4** | Первый multi-client получил audio, но 0 video frames; последующий живой Fluxer цикл показал black screen | **UNVERIFIED / FAIL**, не включать в «играбельно 4P» |

## Проверка отдельного результата

Каждая запись будущего `PASS` обязана содержать **игру/издание/hash, core/runtime/версию, host+guest устройства, сеть (same-LAN или независимые ISP), способ ввода, наблюдаемое действие каждого, Home/Exit/Rejoin, длительность, логи и статус сейвов**. Ни карточка «2 players», ни `Ready`, ни `Session Start` не заменяют игрового результата. [Форма приёмки](MULTIPLAYER_ACCEPTANCE.md).
