# Games: коллекции, платформы, библиотека и действия игры

**Проверка:** `CODE` — просмотр UI и маршрутов `main` bb3d242530753fd956526b793e273d4e74adb02f, 2026-11-03. Физическая проверка каждого сценария и запуска игр **OPEN**.

## Экран Games — что пользователь видит сначала

| Зона | Содержимое | Действие |
| --- | --- | --- |
| **Collections** (верх) | Горизонтальная полоса готовых/пользовательских коллекций, количество игр, собственные обложки/иконки | Открыть коллекцию |
| **New collection** | Кнопка в конце полосы | Создать коллекцию |
| Меню собственной коллекции | Троеточие/долгое нажатие | Редактировать выбранную коллекцию |
| **Platforms** (низ) | Карточки игровых платформ, горизонтальная прокрутка | Открыть платформу |
| Пустая библиотека | «Your consoles will appear here» | Перейти к настройке источника игр |

После выбора коллекции/платформы открывается библиотека, а не отдельный «эмуляторный лаунчер». Названия соседних платформ/коллекций показываются в полосе над каталогом. `L2/R2` переключают соседние контексты без возврата в корень.

Код: [`src/qml/SeriesPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SeriesPage.qml), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L1416-L1479), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L892-L908).

## Обычная игровая библиотека

- **Wheel** — крупная визуальная карусель игр.
- **List** — списочное отображение и страницы.
- **Shelves** — полки обложек.
- **Grid** — сетка изображений / скриншотов.

Режимы реально подключены в QML: [`src/qml/MultiversePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/MultiversePage.qml), [`src/qml/LibraryWheel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/LibraryWheel.qml), [`src/qml/LibraryGameList.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/LibraryGameList.qml), [`src/qml/LibraryShelves.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/LibraryShelves.qml), [`src/qml/LibraryGrid.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/LibraryGrid.qml).

Для списка игр есть действия: **A — Play**, **X — Search**, **Y — Filter**, **L3 — Favorite**, **R3 — View**, **Select — Game actions**, **Hold A — Options** (появляются согласно текущему экрану и возможностям). При выборе обычной игры сам фокус/выбор не запускает её без явного подтверждения. Из PC-библиотеки предусмотрено **+ Add game** (другой установщик и совместимость — отдельный аудит).

Код: [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L518-L526), [`src/qml/MultiversePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/MultiversePage.qml), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L2369-L2380).

## Контекстное окно игры: точные вкладки

UI-контекст `Game / Library / View` (последняя скрывается, если нет сменяемого вида).

| Подвкладка | Пункты по коду | Важные условия |
| --- | --- | --- |
| **Game** | Play together; Multiplayer setup; Game settings; Reviews; **дополнительное название адаптера** | Play together активен только при поддерживаемой конфигурации; Multiplayer setup — когда есть варианты; адаптерная строка только при наличии |
| **Library** | Add to collection, Rename, Information & artwork, File information, Move game, Delete game | Для Steam игра управляется через Steam; пути перемещения/арт зависят от источника и прав |
| **View** | Search library, Filter library, Wheel, List, Shelves, Grid | Отображается только когда браузер поддерживает смену вида |

Дополнительные действия и внутренние диалоги: изменение имени, метаданные/обложки через ScreenScraper, информация о файле/платформе, перенос между папками, удаление с предупреждениями, пользовательские reviews. Наличие review/UI и команд сервиса само по себе не доказывает успешную публикацию на сервер.

Код: [`src/qml/LibraryToolsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/LibraryToolsPanel.qml#L33-L75), [`src/features/library/LibraryToolsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/library/LibraryToolsController.cpp#L89-L147).

## Особые страницы: Worlds / Adventures и адаптеры

Для адаптерно-ориентированных приключений есть страница **Worlds → Region → Adventures → Detail**, в которой могут показываться реальные игровая статистика/прогресс, несколько действий и иллюстрации. Для обычной библиотеки используется универсальный `MultiversePage`. Это **два рендера внутри Games**, а не дополнительные постоянные верхние вкладки.

Активный адаптер может открыть собственную **динамическую верхнюю вкладку** с экранами, которые он зарегистрировал. Перечень возможностей конкретных адаптеров и запись сейвов — **в отдельном аудите адаптеров**, не переносить сюда рекламные утверждения.

Код: [`src/qml/WorldsPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/WorldsPage.qml), [`src/qml/MultiversePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/MultiversePage.qml), [`src/qml/GameHubPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/GameHubPage.qml), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L603-L633).

## Откуда игры и как готовятся

Отдельные панели/настройки обеспечивают пользовательские входы: **Settings → Games & library → Collections / Scan library now / Game storage / ScreenScraper / Library scanning / Game preparation**. Окно подготовки содержит выбор платформы, **Import BIOS pack**, реестр недостающих BIOS/firmware и переход к Online setup. Это **интерфейсный маршрут**, не доказательство полной автоматической совместимости/успешного импорта каждой прошивки.

Код: [`src/features/settings/SettingsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/settings/SettingsController.cpp#L155-L177), [`src/qml/GamePreparationPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/GamePreparationPanel.qml).

## Наблюдения и недоделанные проверки

1. Пустое состояние на Games рекомендует «Start → Library», но текущий Start показывает Settings/Power/Switch + виджеты: нужен UX-текст/переход к действующему пункту **Settings → Games & library**. [`src/qml/SeriesPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SeriesPage.qml#L203-L206), [`src/qml/ControlsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/ControlsPanel.qml#L38-L45).
2. Сменяемый вид, кнопки и меню в исходниках есть; без установленного контента часть будет пустой/неактивной. **Не объявлять полноценное покрытие игровых платформ**.
3. **Play together / Multiplayer setup** — только входы в отдельный будущий аудит режимов и списка игр.
4. Проверить на устройстве длинные названия, количество коллекций/платформ, прокрутку, поиск, фильтр, отображения, избранное и реальный запуск с возвратом.
