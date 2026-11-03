# TrainerOS Alpha — аудит мультиплеера: система и границы

**Дата:** 2026-11-03. **Срез реализации:** `main` @ `e4e16a713e3496042d4284f3f8ec7b337f98fc80`. Проверялись C++/QML/Python, документы, прежние результаты тестов и реальные свидетельства Flip/Odin. **Новая сборка, установка и физический матч в этом аудите не выполнялись.** Датированные свидетельства не заменяют приёмку итогового alpha-кандидата.

**Решение владельца 3 ноября:** альфа может выйти с незавершёнными мультиплеерными режимами; это **не автоматический блокер выпуска**, но все ограничения должны быть честно перечислены. Поставка/сохранение данных и законность распространения остаются обязательными. [Решение и состав runtime](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_RELEASE_MATRIX_RU.md).

## Карта механизмов

| Подсистема | Для пользователя | Протокол / модель | Статус |
| --- | --- | --- | --- |
| Lobby | Комнаты, приглашения, поиск, места, Ready, запуск | `LobbySession` + `LobbyRuntime`, Fluxer Online или Local TLS | CODE, есть UI/native/device tests; полная приёмка текущей альфы OPEN |
| Shared-console NetPlay | Игроки управляют разными портами одной виртуальной консоли | RetroArch rollback/lockstep, штатные cores и relay | CODE, реальные парные игры NES/SNES/Mega Drive и др. |
| Linked machines | У каждого своя виртуальная консоль и сейвы | Cable/RFU/wireless, native LAN, GGPO/кабинеты, ICE/DTLS | CODE, результаты очень различаются по платформам |
| Native game Online | Внутриигровой LAN или серверный сервис | PS2 DEV9, Xbox System Link, Dolphin BBA, Wii/DS/3DS/WiiU etc. | Частично: наличие клиента ≠ проверенный онлайн-матч |
| Remote Play | Одна игра на хосте, гости получают картинку и управление | Прямой ICE/STUN, H.264/Opus, remote pads | 2P парный старый тест; 3–4 client media **не принята** |
| Go Live / Watch | Зритель смотрит чужую игру без ROM и контроллера | Fluxer LiveKit + game-scoped capture | Парная передача видео/тонов проверялась, не нагрузочный WAN |
| Group voice | Один независимый звонок во время разных игр | Fluxer/LiveKit | Проверена непрерывность синтетического звука, не человеческая речь |
| Nearby Link | Trade/Sell/Give/Battle на поддерживаемых сейвах | Bluetooth RFCOMM / локальные соединения, Wi-Fi Direct эксперимент | Отличается от NetPlay и Local Lobby |

Это принципиально **разные** возможности. Зрительское видео нельзя называть Remote Play, Local Lobby не становится интернет-лобби, а общий каталог игр не означает проверенный multiplayer каждой ROM.

## Где это расположено

Актуальный путь — **Online → Lobby** (старые документы называют `GameHub → Lobby`; теперь `openGameHubFace("lobby")` перенаправляет в Online). Другие входы: Home → Create/My Lobbies, Games → контекст **Play together**, действия Social, приглашения и Game Options.

```text
Online → Lobby
├── Online / Local (одна локальная сеть, без Fluxer)
├── Search, категории, свободные места, фильтры, Refresh
├── My Lobbies / Create Lobby
│   └── connection / name / game / category / access / time
└── Room
    ├── game + mode / connection settings
    ├── аватары, места P1…P4, spectators
    ├── Game Picker, варианты для голосования, Vote
    ├── Prepare → Ready/Not ready → Start (только организатор)
    ├── чат, вызов и зрители
    └── игра → Home/Game Options → Exit или разрешённый Rejoin
```

**Лимит комнаты — 16 участников ВСЕГО, включая зрителей; не 16 одновременных игровых контроллеров.** В текущем `RuntimeMultiplayer::prepareChecked` фактическая подготовка игроков ограничена `qMin(4,profile.players)`, а отдельные runtime допускают меньше. Организатор P1, все играющие должны быть подключены и подготовлены. Start явный: «все готовы» не запускает игру. Комната может существовать без выбранной игры («Choosing Together»).

Код: [навигация](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/core/navigation/ShellController.cpp), [правила комнаты](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/LobbySession.cpp), [подготовка/запуск](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/LobbyRuntime.cpp), [допуск](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/adventure/RuntimeLobby.cpp).

## Что проверяется до Ready и перед Start

`RuntimeMultiplayer` находит локальный ROM/образ и его реальную идентичность, runtime profile, ядро/настройки/BIOS и нужные сетевые helpers. Сканирует **выбранную** игру по требованию, а не хеширует всю библиотеку при старте. Различает отсутствующий контент и установленный контент с **несовместимым runtime**. При работающей игре не выполняет молча второй запуск: требуется подтверждённое сохранение/выход, отмена безопасна. Перед запуском повторно проверяются revision, content path, mode, generation, ticket и состав комнаты. Для Linked-профилей требуются последовательные независимые места.

Успешный Prepare/Ready **не доказывает**, что эмулятор открылся, договорился о сети и игроки влияют на одну игру. `LobbySession::acknowledgeLaunch` различает намерение и подтверждение; ошибки не должны уничтожать разговор/комнату. [runtime discovery](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/adventure/RuntimeMultiplayer.cpp), [prepareChecked/launch](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/adventure/RuntimeLobby.cpp), [восстановление запуска](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY63_PREPARATION.md).

## Сетевой транспорт

| Метод | Где применим | Реальная граница |
| --- | --- | --- |
| RetroArch relay | NES/SNES/MD/FBNeo и другие точные cores | Auto по всем игрокам выбирает регион Madrid/New York/São Paulo/Singapore, есть ручной выбор. Пробный TCP ping ≠ гарантия latency. |
| PSP relay | PPSSPP Ad Hoc | Standard public либо временный relay на host handheld с ICE/DTLS; host-relay сейчас 2P. |
| Native LAN carrier | PS2 DEV9, xemu, Dolphin BBA, NGPC, Model 3, Flycast cabinet, Doom | Общий room-bound ICE/DTLS между отдельными игровыми протоколами; no universal NAT fallback. |
| Local Lobby | Same Ethernet/Wi-Fi без Fluxer | UDP discovery + TLS, исходники и loopback-тесты; не доказана физическая пользовательская пара в свежей сборке. |
| Remote Play | Видео/звук + input из одного процесса хоста | Прямой ICE и публичный STUN, **нет TURN/owner media relay**; плохой NAT может остановить соединение. |
| Watch/Go Live | Трансляция выбранной игры звонящим/зрителям | Fluxer LiveKit; отдельный от Remote Play поток без возможности управлять. |
| Bluetooth/Wi-Fi Direct | Nearby сохранения/Link | Bluetooth поддержан, Wi-Fi Direct только явно экспериментальный; **не** транспорт всех Lobby-NetPlay маршрутов. |

Подробнее: [MULTIPLAYER_TRANSPORT_MEDIA.md](MULTIPLAYER_TRANSPORT_MEDIA.md).

## Доказательства, а не маркетинговые обещания

**Реальные парные игровые действия** уже описаны для NES Pong, SNES Contra III, MD Streets of Rage 2, PSP Ridge Racer/Virtua Tennis/Killzone/Shin Budokai/Lumines/Tekken, GameCube Melee, Vita vitaQuake и ряда других. **Sonic Rivals 2 имеет воспроизводимый отказ**, а PS2 Battlefront II — известные дефекты утилиты сети. Внешний relay через два устройства за одним домашним маршрутизатором **не является тестом через две независимые сети**. Полный список с точными методами: [MULTIPLAYER_TESTED_GAMES.md](MULTIPLAYER_TESTED_GAMES.md).

**Remote Play**: установленный парный маршрут 14 октября с NES Pong Flip→Odin, видеокадрами и явным повторным входом при живом host PID. В `main` предусмотрены несколько гостей, но многогостевой тест получал звук без видеокадров, а следующий заход через Fluxer — чёрный экран. **Не объявлять «4-player Remote Play готов»**. На 25 октября базовая Armada/Iris обновлялась, предыдущий patched IDR тест уже не доказывает состояние нового драйвера. [2P](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/REMOTE_PLAY_LOBBY.md), [multi-guest failure](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/REMOTE_PLAY_GROUPS.md), [Iris change](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/ARMADA_IRIS_ENCODER.md).

**Временные гости и rejoin**: в ряде RetroArch профилей вручную разрешено `Rejoin game`, host остаётся в игре, участнику резервируется прежний порт до 180 секунд. Это **не автоматический rejoin** и не распространяется на все link/native платформы. [точный контракт](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY_LIVE_JOIN.md).

**Отсутствие ROM/BIOS в наборе**: Setup должен поставлять точные нужные сетевые runtime/helper, но личные образы, BIOS, console identity и пароли сторонних сервисов остаются собственностью игрока. 3 ноября на Flip доставлен hybrid runtime и проверен вход в выбор сетевого режима из NES Pong, **не проводился новый матч**. [3.11 setup evidence](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/evidence/2026-11-03-hybrid-runtime/README.md).

## Наблюдаемые противоречия и важные OPEN

1. Старое [LOBBY.md](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY.md) обещает передачу организатора при Leave; текущий `LobbyRoomCoordinator::leave` **закрывает комнату и рассылает closed** — расхождение код/описание.
2. [бот-каталог](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/services/lobby-directory/README.md) фиксирует source-лимит 16 от 25 октября, но обновлённый бот там же указан **не развёрнутым**. Server deployment проверить.
3. **Local Lobby** имеет код и loopback/TLS smoke, но датированный документ не считает это физической приёмкой двух устройств.
4. **Remote Play 3/4 и физическое качество H.264/Opus после смены ядра** не закрыты.
5. Реальные двусторонние сети, 3–4 физических клиентов, headset/mic/echo, совместимость всех игр и долговременная нагрузка не сертифицированы.
6. **PC native LAN #251, PS3/Switch multiplayer, широкий Wii U/Vita Online** — не включать в завершённые Alpha-функции.
7. Список владельца из [321→314+5 игр](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_SELECTION_DELIVERY.md) — набор образов/кандидатов, а **не список протестированных multiplayer игр**.

**Следующие файлы:** [весь Lobby](MULTIPLAYER_LOBBY.md), [все семейства](MULTIPLAYER_PLATFORMS.md), [матчи](MULTIPLAYER_TESTED_GAMES.md), [риски](MULTIPLAYER_RISKS.md), [проверки релиза](MULTIPLAYER_ACCEPTANCE.md), [описание для игрока](../blocks/MULTIPLAYER.md).