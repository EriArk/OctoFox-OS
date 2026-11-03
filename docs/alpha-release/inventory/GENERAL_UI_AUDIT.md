# Общий аудит интерфейса TrainerOS — вкладки, разделы и действия

**Дата:** 2026-11-03. **Тип проверки:** чтение реализации интерфейса и маршрутизации на `main`; источник среза `bb3d242530753fd956526b793e273d4e74adb02f`. **Не является физическим тестом** и не доказывает наличие всех функций в публичной сборке.

## Границы первого прохода

- Разобраны основные вкладки, внутренние разделы, переходы, Home, системные/контекстные окна, профиль, общие Settings, Apps/Browser/Files и пользовательские входы в Social.
- **В отдельном аудите:** функциональность Crates (каталог, жизненный цикл пакетов, разрешения, интеграции), адаптеры отдельных игр, конкретная совместимость эмуляторов и **весь мультиплеер** (Lobby/NetPlay/Remote Play/Nearby/голос/релеи).
- Статус **UI CODE** означает, что элемент и его обработчик присутствуют в исходниках; не подтверждает end-to-end работу внешнего сервиса. Все физические проверки ниже остаются **OPEN**, если не дана конкретная ссылка на датированную приёмку.

## 1. Дерево навигации — текущий код

| Верхняя вкладка | Вложенные разделы / поверхности | Что видно игроку | Граница аудита |
| --- | --- | --- | --- |
| **Home** | Карточка игры; друзья; Lobby-card; достижения; домашний виджет; Screens | Играть/вернуться, переходить к людям, просмотру достижений/скриншотов, открыть виджет | UI CODE |
| **Games** | Корень **Collections** (пользовательские и готовые) и **Platforms**; браузер игр; специальные Worlds/Adventures | Выбор библиотеки, платформы и игры, поиск/фильтры/вид, меню игры | UI CODE |
| **Название адаптера** (динамический GameHub) | Группы/экраны, предоставляемые адаптером | Собственное пространство поддерживаемой игры | UI CODE, конкретные адаптеры позже |
| **Online** | **Lobby**, **Bazaar**, **Crates**, **Chats** | Сетевые комнаты; заглушка Bazaar; каталог Crates; общение | Lobby/Crates отдельно, Bazaar — заглушка |
| → Chats | **Messages**, **Communities**, **Discover** | Переписки, сообщества, поиск людей/сообществ | UI CODE; онлайн-проверки отдельно |
| **Apps** | **Apps**, **Browser**, **Files** | Каталог приложений, веб-браузер, файловый менеджер | UI CODE; end-to-end зависит от окружения |

В коде верхний набор фиксирован по индексам: `home / games / gamehub / online / apps`, но **вкладка gamehub не отображается без адаптера**. Она называется меткой активного адаптера, а не обязательно «GameHub». Для обычной игры попытка открыть этот индекс возвращает на Home.

Источники: [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L597-L610), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L892-L908), [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L153-L167), [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L317-L330).

## 2. Глобальная навигация и слои

| Действие | Текущий маршрут / смысл | Источник |
| --- | --- | --- |
| Нажать верхнюю вкладку; **L1/R1** | Переключить основные вкладки; невидимый GameHub пропускается при плечевой навигации | [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L2258-L2268) |
| **L2/R2** | Переключить вложенную «грань» текущей вкладки: платформы/коллекции, группы адаптера, Online или Apps. При модальном окне может быть заблокировано | [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L645-L675) |
| **A / B** | Подтвердить / назад; контекст зависит от выбранного экрана | [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L463-L543) |
| **X / Y** вне модального сценария | Quick Apps / Recent games; в браузере игр X=поиск, Y=фильтр, L3=избранное, R3=вид | [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L518-L552) |
| **Select**, **удержание A** | Контекстные действия для игры, коллекции или приложения; не универсально на каждом экране | [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L518-L540) |
| **Home** | Возврат к оболочке / Game Options при запущенной игре, зависит от runtime-оверлея | [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L573-L575) |
| **Start** | Системная панель быстрого доступа и виджетов; не является игровым меню | [`src/qml/ControlsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/ControlsPanel.qml#L38-L45) |
| Верхняя иконка профиля / колокольчик | Профиль игрока / уведомления, включая звонки и переходы по сообщению | [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L96-L149) |

При смене основной вкладки контроллер намеренно **сохраняет вложенный маршрут и фокус**, а не сбрасывает интерфейс на корневой экран. Открытые сервисные/модальные панели закрываются по правилам перехода. Источник: [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L1364-L1415).

## 3. Границы «есть кнопка» и «работает»

| Подсистема | Подтверждение по коду | Что не подтверждено этим аудитом |
| --- | --- | --- |
| Home / выбор виджета | Кнопки, списки, действия, данные из контроллера | Поставка/работа каждого внешнего виджета |
| Games | Виды, каталог, контекстные команды, переходы | Все ROM/BIOS, каждый core и платформа |
| GameHub | Динамическая навигация по adapter-provided screens | Фактические возможности каждого адаптера и всех игр |
| Chat / Communities / Discover | Вход через Fluxer, списки, окно переписки, поиск, меню | Работа чужих аккаунтов, всех вложений, групповых вызовов и сетей |
| Lobby | Отдельный Online-маршрут и UI-контейнер | Подготовка игроков, NetPlay, Remote Play и синхронизация — отдельный аудит |
| Bazaar | Текстовый экран-заглушка | **Миры/комнаты/обмены в этом build не доступны** |
| Crates | Выбор Online → Crates, открытие каталога | Установка, обновления, плагины, права пакетов — отдельный аудит |
| Apps | Каталог/действия запуска, избранное/скрытые, Quick Apps | Запуск и возврат каждого стороннего приложения |
| Browser | WebEngine-путь, вкладки, история, закладки, файловые запросы | Наличие встроенного веб-движка в каждой сборке; работа всех сайтов |
| Files | Панели мест, путей, файлов | Все реальные операции/права для разных накопителей |
| Settings | Разделы, контроллеры настроек и обработчики | Каждая аппаратная интеграция/служба на каждом устройстве |

## 4. Подтверждённые несовпадения, которые нельзя копировать в посты

1. **GameHub не постоянная общая вкладка**. На верхней полосе её имя/видимость определяет наличие и метка адаптера. Старые описания «GameHub → Overview/RA/Lobby» не являются точным текущим деревом: `overview` и `ra` переводят в **профиль игрока**, `lobby` — в **Online/Lobby**. [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L626-L633).
2. **Crates находится в Online**, а не во внутренней полосе Apps. Полоса Apps — **Apps / Browser / Files**. [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L892-L907).
3. **Bazaar показывает заглушку** «Worlds and player rooms are not available in this build yet», не настоящий общий мир. [`src/qml/OnlinePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/OnlinePage.qml#L37-L45).
4. **Home и Start различаются**: Home — игровая домашняя страница; Start — редактируемая системная панель с контролами. [`src/qml/HomeDashboard.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/HomeDashboard.qml), [`src/qml/ControlsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/ControlsPanel.qml).
5. **Надпись пустой Games-библиотеки «Add games in Start → Library» требует сверки**: текущий Start — ControlsPanel с Settings/Power/Switch, управление библиотекой доступно через Settings → Games & library; прямой пункт Library в этом Start не виден. [`src/qml/SeriesPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SeriesPage.qml#L203-L206), [`src/qml/ControlsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/ControlsPanel.qml#L38-L45). Это возможный UI-copy баг, а не доказательство отсутствия импорта.
6. **Сон во время работающей игры не обещать**: код запрещает такой переход до проверки live-game sleep. [`src/app/Main.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/app/Main.cpp#L735-L750).
7. Пункты **Background music**, вибрация зарядки и подсветка устройства в Settings имеют `unavailable` / «not verified», не выдавать за готовые настройки. [`src/features/settings/SettingsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/settings/SettingsController.cpp#L126-L140).

## 5. Источники проверки и качество доказательств

- Основная маршрутизация: [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp), экранная сборка [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml).
- Исходники страниц: [`src/qml/HomeDashboard.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/HomeDashboard.qml), [`src/qml/SeriesPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SeriesPage.qml), [`src/qml/MultiversePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/MultiversePage.qml), [`src/qml/WorldsPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/WorldsPage.qml), [`src/qml/OnlinePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/OnlinePage.qml), [`src/qml/AppsPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/AppsPage.qml), [`src/qml/SettingsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SettingsPanel.qml).
- Сценарии smoke-тестов **существуют**, но в этом проходе не запускались: [`tests/ui/HomeSmokeScenario.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/tests/ui/HomeSmokeScenario.cpp), [`tests/ui/AppsSmokeScenario.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/tests/ui/AppsSmokeScenario.cpp), [`tests/ui/SettingsSmokeScenario.h`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/tests/ui/SettingsSmokeScenario.h), [`tests/ui/LibrarySmokeScenario.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/tests/ui/LibrarySmokeScenario.cpp). Например, тест Apps прямо использует имитационный каталог и не выполняет настоящий запуск приложения.
- Датированная физическая проверка установки/сессии на Flip и входа в сервисы описана в [PREBETA_RELEASE_RU](../../PREBETA_RELEASE_RU.md), но не служит доказательством полного покрытия всех экранов и функций этого audit snapshot.

## Детальные отчёты первого прохода

- [Оболочка, Home, Start, профиль и Game Options](../blocks/SHELL.md)
- [Games, коллекции, платформы и меню игр](../blocks/GAMES.md)
- [Online/Chats/Communities/Discover](../blocks/SOCIAL.md)
- [Apps, Browser, Files, Quick Apps](../blocks/APPS.md)
- [Settings — точные разделы и состояния](../blocks/SETTINGS.md)
- [Матрица ручной приёмки UI](GENERAL_UI_ACCEPTANCE.md)

**Следующий отдельный этап:** аудит Crates по собственным компонентам и lifecycle, затем аудит мультиплеера по режимам и проверенным играм. Не смешивать их с этим документом.
