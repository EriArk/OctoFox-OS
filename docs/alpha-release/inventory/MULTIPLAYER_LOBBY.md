# Lobby — подробный аудит экранов, состояний и допусков

**Срез:** `e4e16a713e3496042d4284f3f8ec7b337f98fc80`, 2026-11-03; `CODE` и исторические тесты, не новый физический полный запуск.

## Экранные элементы

| Место | Что есть в интерфейсе | Действие / результат |
| --- | --- | --- |
| Online → Lobby | Выбор **Online / Local** | Online требует Fluxer, Local — одна сеть Wi-Fi/Ethernet без аккаунта |
| Каталог | Search rooms; All rooms, Racing, Fighting, Adventure, Party Games, Competitive, Other games | Фильтр, карточки комнат 2×3 и страницы; отдельные Free seats/Filters |
| Кнопки каталога | Create lobby / My Lobbies, Refresh | Новая комната либо список ранее созданных; manual refresh |
| Create Lobby | Connection; Name; Game; Category; Access; When | При Local доступ/расписание скрыты; Cancel не публикует черновик |
| Game Picker | Группы, доступные игры, варианты способа multiplayer | Выбор game+mode; до 4 Proposed, голосование за разные game/mode |
| Room | Title, cover, status, хозяин, P1…Pn, spectators, Room options, Leave | Участники выбирают свободный слот; наблюдатели не управляют |
| Room → Game | Choose a game / Import your game / Connection settings / Start | Import появляется при `local-content`, Start только у хозяина после Ready всех |
| Room → Actions | Invite, Prepare/Retry, Ready/Not ready, vote, spectate, join-live и др. по наличию прав | Действия не дают прав отсутствующему участнику |
| Чат/Call | Общий разговор Fluxer и мини-чат; для Local нет provider voice | Уход из game party не должен отключать групповой звонок |
| Home / Social / Game Options | Другие входы в тот же room | Никакого второго параллельного Lobby-механизма |

Источники: [каталог](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/qml/LobbyCatalogue.qml), [wizard](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/qml/LobbyCreatePopup.qml), [комната](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/qml/LobbyRoom.qml), [picker](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/qml/LobbyGamePicker.qml), [создание](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/SocialLobbyCreation.cpp), [действия](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/SocialLobbyRoom.cpp). Старые документы помещают Lobby в GameHub; текущий переход см. [ShellController](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/core/navigation/ShellController.cpp).

## Политики, численность и голосование

- Для Online политики `private` («Invite only»), `public` («Open»), `approval` («By request»). Local комната не становится online при переключении каталога.
- Room max **16 участников** включая spectators и owner, не 16 игровых мест. Local/Online разделены; несколько запланированных комнат можно сохранить, но Ready/game/runtime — одна активная.
- `LobbySession` допускает до 16 мест в описателе игры, но текущая **подготовка runtime ограничивает 4**, а отдельный профиль — 2. P1 обязателен у хозяина для supported profiles, linked seats должны идти без пропуска.
- Voting: 2–4 предложения game+mode, один вариант на игрока, spectator не голосует, хозяин подтверждает результат, не проигрывающий по голосам. Голосование сбрасывает Ready, не запускает игру.
- «Preparing» — не процент и не Ready; Ready доступен только после успешной локальной проверки. Изменение игры, порта, relay/режима или поколения сбрасывает готовность.
- Start — только **явное действие хозяина**, `canStart` требует всех подключённых, подготовленных и ready, включая самого хозяина; зрители не учитываются.

Код: [state, permission, vote, ready](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/LobbySession.cpp), [runtime preconditions](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/adventure/RuntimeLobby.cpp).

## Lifecycle / аварии

| Phase/событие | Семантика | Защита |
| --- | --- | --- |
| `choosing` | Комната без игры, можно собираться и предлагать игры | Нет runtime |
| `gathering` | Выбрана игра, проводится локальная проверка и Ready | Подписанные generation/участники |
| `launching` | Хозяин нажал Start; есть ticket | Отправленная команда — не `playing`, ждём результаты |
| `playing` | Участники подтвердили запуск | Process игры и членство комнаты живут отдельно |
| Выход/отключение гостя | Не обязан закрывать комнату, звонок, игру хозяина | Поддержанный ручной rejoin; во многих семействах rejoin неизвестен |
| Restart shell | Восстанавливаются допустимые membership/room, но НЕ Ready, старый ticket, неотвеченное приглашение или чужой аккаунт | Checkpoint сам по себе не даёт разрешение |
| Транзиторная сеть | heartbeat/retry, не приравнивать delivery failure к membership-ended | Защита от запоздалого сообщения и старых поколений |
| Обычный Save/Exit | Finalizer должен завершиться до нового запуска | Отказ сохранения не открывает новую игру |
| Leave хозяина | Текущий `LobbyRoomCoordinator::leave()` рассылает `closed`, `LobbySession::leave(owner)` закрывает room | Старое обещание `transfer ownership on Leave` в `LOBBY.md` не соответствует реализации |

**Rejoin** для проверенных профилей: автоматическое восстановление signaling, но только явное `Rejoin game` может запустить гостевую игру; прежнее место держится до **180 секунд**, после требуется новый допуск. Не ставить «автоматически возвращает в игру». [L06](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY_LIVE_JOIN.md), [L04](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY_RECOVERY.md), [L63](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY63_PREPARATION.md).

## Local без Fluxer

Использует `LocalLobbyTransport`: UDP discovery, собственный сертифицированный TLS peer identity, ограниченный список, явное одобрение хозяина. Комната/local checkpoint хранятся отдельно от Fluxer. Не содержит провайдерский голос или внешний интернет-каталог; не подразумевает Remote Play и online-only runtime. [реализация](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/platform/network/LocalLobbyTransport.cpp), [UI/room bridge](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/SocialLocalLobby.cpp), [контракт и петлевые тесты](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/OFFLINE_LOBBY.md). **Loopback/QtTests не являются свежей 2-device физической приёмкой**.

## Что считается подтверждённым

Имеются `tests/LobbyTests.cpp`, `LocalLobbyTests.cpp`, `GamePartyTests.cpp`, `RuntimeMultiplayerTests.cpp`: permission, 16 participants, votes, ready/host-start, room recovery, stale ticket, consent, предотвращение второго запуска. Датированы отдельные успешные UI/ARM тесты и установленный Flip/Odin picker (в том числе 160-кандидатный QML-скролл), **но** не доказана вся цепочка через WAN на итоговом alpha Setup. Бот-каталог 16-participant source change от 25.10 по его README ещё ожидает deployment.

**Результат аудита:** ROOM CODE — да, реальный ограниченный маршрут Online GAMEPLAY — да, полноценная 16-member/4-player/Offline/WAN acceptance для новой альфы — **OPEN**.