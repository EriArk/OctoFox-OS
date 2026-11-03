# Матрица функций TrainerOS — альфа

**Статус:** матрица живого аудита. [Первый проход по общему UI](GENERAL_UI_AUDIT.md) завершён по исходникам; Crates и мультиплеер разобраны отдельно по коду/предыдущим доказательствам; итоговая альфа ещё требует приёмки. `CODE` здесь подтверждает **доступный UI/маршрут**, но не полноту backend или физическую работу. `?` = не проаудировано для этой матрицы.

Для каждой функции в дальнейшем записывать: **точное действие игрока**, ветку/ревизию, код, результат физической проверки, ограничения, ссылку на issue/тест и готовность к публичному описанию. При необходимости дробить строки до отдельных кнопок, меню и сценариев.

| ID | Блок / граница аудита | CODE | INSTALLED | TESTED | Первичный источник |
| --- | --- | :---: | :---: | :---: | --- |
| F01 | Загрузка системы, отдельная сессия, переход Desktop ↔ TrainerOS | ? | ? | ? | [PREBETA](../../PREBETA_RELEASE_RU.md) |
| F02 | Первый запуск, Setup, мастер профиля | ? | ? | ? | [FIRST_RUN](../../FIRST_RUN.md) |
| F03 | Локальные профили, вход, аккаунт TrainerOS, сохранение состояния | PARTIAL | ? | ? | [DATA_MODEL](../../DATA_MODEL.md) |
| F04 | Home, Options, Dashboard, уведомления | CODE | ? | ? | [PRODUCT_SPEC](../../PRODUCT_SPEC.md) |
| F05 | Games: платформы, коллекции, фильтры, режимы отображения | CODE | ? | ? | [LIBRARY](../../LIBRARY_AND_LAUNCH.md) |
| F06 | Сканирование библиотеки, метаданные и ScreenScraper | PARTIAL | ? | ? | [SCREENSCRAPER](../../SCREENSCRAPER.md) |
| F07 | Запуск игр, выбор runtime/core/BIOS, переход обратно | ? | ? | ? | [EMULATOR_STANDARD](../../EMULATOR_STANDARD.md) |
| F08 | GameHub, вкладки игры и действия | CODE | ? | ? | [PRODUCT_SPEC](../../PRODUCT_SPEC.md) |
| F09 | Game Options, сворачивание, возврат, выход, оверлей | CODE | ? | ? | [HOME_HISTORY](../../HOME_AND_HISTORY.md) |
| F10 | RetroAchievements, достижения, история и прогресс | PARTIAL | ? | ? | [GAME_PROGRESS](../../GAME_PROGRESS.md) |
| F11 | Адаптеры и Adventure: чтение игровых данных | ? | ? | ? | [adapters](../../adapters/README.md) |
| F12 | Запись сохранений, защита, восстановление, изоляция профилей | ? | ? | ? | [SAVE_LINEAGE](../../SAVE_LINEAGE.md) |
| F13 | Связанные с игрой сервисы, мир, коллекции и Link | ? | ? | ? | [ADVENTURE](../../ADVENTURE_EXIT.md) |
| F14 | Social: друзья, личные сообщения, приглашения | CODE | ? | ? | [SOCIAL](../../SOCIAL.md) |
| F15 | Сообщества/группы, Discover, права и действия | CODE | ? | ? | [SOCIAL](../../SOCIAL.md) |
| F16 | Звонки, голос и звуковое поведение в игре | PARTIAL | ? | ? | [CALL83](../../CALL83.md) |
| F17 | Lobby: типы, выбор игры, места, готовность, старт | CODE | PARTIAL | PARTIAL | [AUDIT](MULTIPLAYER_AUDIT.md) · [LOBBY](../../LOBBY.md) |
| F18 | NetPlay: соединение, совместимость, синхронизация | CODE | PARTIAL | PARTIAL | [AUDIT](MULTIPLAYER_AUDIT.md) · [MULTIPLAYER_MATRIX](../../EMULATOR_MULTIPLAYER_MATRIX.md) |
| F19 | Remote Play, демонстрация/просмотр и зрители | PARTIAL | PARTIAL | PARTIAL | [AUDIT](MULTIPLAYER_AUDIT.md) · [REMOTE_PLAY](../../REMOTE_PLAY_TRANSPORT.md) |
| F20 | LAN/Internet multiplayer, маршруты, прямые подключения/relay | PARTIAL | PARTIAL | PARTIAL | [AUDIT](MULTIPLAYER_AUDIT.md) · [TRANSPORT_AUDIT](../../MULTIPLAYER_TRANSPORT_AUDIT.md) |
| F21 | Подготовка игры к лобби, совместимость, импорт, отмена | CODE | PARTIAL | PARTIAL | [AUDIT](MULTIPLAYER_AUDIT.md) · [GAME_PREPARATION](../../GAME_PREPARATION.md) |
| F22 | Nearby, Bluetooth, Wi-Fi Direct и локальные возможности | PARTIAL | PARTIAL | PARTIAL | [AUDIT](MULTIPLAYER_AUDIT.md) · [NEARBY_PLAY](../../NEARBY_PLAY.md) |
| F23 | Apps: Files, Browser и обычные приложения | CODE | ? | ? | [APPS](../../APPS_WORKSPACE_RU.md) |
| F24 | Crates: каталог, приложения, расширения, установка | CODE | PARTIAL | PARTIAL | [CRATES AUDIT](CRATES_AUDIT.md) · [device evidence](../../CRATES77_CATALOGUE.md) |
| F25 | QuickApps, многозадачность, быстрые действия/виджеты | CODE | ? | ? | [PRODUCT_SPEC](../../PRODUCT_SPEC.md) |
| F26 | Settings: ввод, экран, аудио, сеть, аккаунты | CODE | ? | ? | [DEVICE_CONTROLS](../../DEVICE_CONTROLS.md) |
| F27 | Установка, Software/OTA, обновление, откат, удаление | ? | ? | ? | [FULL_BUNDLE](../../FULL_BUNDLE_RU.md) |
| F28 | PC-игры, Steam, Proton, установщик, ярлыки | ? | ? | ? | [PRODUCT_ARCH](../../PRODUCT_ARCHITECTURE_RU.md) |
| F29 | SDK для приложений/виджетов/адаптеров, интеграции | ? | ? | ? | [SDK](../../../sdk/README.md) |
| F30 | Экономика, Sparks, подписка, связь с аккаунтом | PARTIAL | ? | ? | [ECONOMY](../../TRAINEROS_ACCOUNT_ECONOMY_RU.md) |
| F31 | Bazaar, обмены, сообщества и мини-игры | PARTIAL | ? | ? | [BAZAAR](../../BAZAAR.md) |
| F32 | Безопасность, offline-режимы, приватность, права | ? | ? | ? | [SECURITY](../../../SECURITY.md) |
| F33 | FPS/Performance, диагностика, ресурсы, ограничения устройства | ? | ? | ? | [PERFORMANCE](../../GAME_PERFORMANCE.md) |

**Расшифровка этого прохода:** F03/F06/F10/F16/F30/F31 = `PARTIAL` только UI/часть маршрутов, не end-to-end; остальные отмеченные `CODE` = видимый экран и путь к обработчику. `INSTALLED`/`TESTED` оставлены `?`, пока не привязаны к финальному release commit и датированному результату. Для Crates (F24) зафиксированы код и ограниченные *исторические* физические/тестовые подтверждения (см. [Crates audit](CRATES_AUDIT.md)); все части Crates и итоговый альфа-кандидат не приняты. Мультиплеер (F17–F22) теперь разобран в [MULTIPLAYER_AUDIT](MULTIPLAYER_AUDIT.md), [PLATFORMS](MULTIPLAYER_PLATFORMS.md), [TESTED_GAMES](MULTIPLAYER_TESTED_GAMES.md), [RISKS](MULTIPLAYER_RISKS.md): PARTIAL у Installed/TESTED означает только **предыдущие узкие проверки**. Не маркировать как PASS релиза. Подробности: [общий аудит](GENERAL_UI_AUDIT.md), [приёмка](GENERAL_UI_ACCEPTANCE.md).

## Карточка уточнения одной строки

| Поле | Запись |
| --- | --- |
| ID, конкретная функция | |
| Сценарий игрока / где находится | |
| Ветка, SHA, версия и устройство | |
| Доказательства кода / теста | |
| Статусы CODE / INSTALLED / TESTED | |
| Что точно работает и на каких играх | |
| Что НЕ работает / не проверено | |
| Риск для альфы: блокер / ограничение / не относится | |
| Можно ли обещать в анонсе? | |

Готовые блоки постепенно превращаются в отдельные документы [в каталоге blocks](../blocks/INDEX.md).
