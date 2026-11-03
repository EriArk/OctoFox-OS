# Общая оболочка: Home, навигация, Start, профиль, Game Options

**Проверка:** `CODE` (маршруты, QML и обработчики), срез `main` bb3d242530753fd956526b793e273d4e74adb02f от 2026-11-03. **Физическая приёмка этого среза: OPEN.**

## Оболочка и верхняя полоса

Основной горизонтальный набор: `Home`, `Games`, **вкладка поддерживаемого адаптера, если есть**, `Online`, `Apps`. Верхний профиль содержит имя/аватар, уровень и баланс Sparks, а также индикатор текущей игры; справа колокольчик уведомлений. Основные и вторичные полосы доступны мышью/касанием и контроллером. Выбранные внутренние маршруты сохраняются при переключении вкладок.

Код: [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L96-L167), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L597-L610), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L1364-L1415).

## Home: что находится на странице

| Область | Что показывает | Что делает пользователь | Граница |
| --- | --- | --- | --- |
| Верхний блок слева | Текущее/своё лобби, либо «Create lobby» | Открыть свои комнаты или начало создания | Сеть/готовность комнат — отдельный аудит |
| Лента друзей | Аватары, имена, отметки непрочитанного; пустое состояние | Перейти в переписку или профиль человека | Синхронизация требует Fluxer |
| Слот виджета | Выбранный Home-widget, кнопка изменения | Выбрать/заменить/открыть виджет | Установка внешних виджетов отдельно |
| Главная карточка | Обложка/фон игры, описание/адаптерный контент, метаданные, кнопка Play / Return | Начать игру либо вернуться к уже запущенной | Runtime-launch отдельно |
| Недавние достижения | Иконки, заголовки, пустое состояние | Открыть карточку конкретного достижения | Требует данных RA |
| Screens | Коллаж изображений из истории | Открыть профиль → Screens | Изображения зависят от доступных captures |

Встроенные варианты виджета: **Downloads, Storage, Clock, Battery, No widget** и отдельно установленные виджеты. Кнопка зависит от контекста. Слой Home не означает полной свободы расположения всех областей: редактируемым здесь является отдельный слот виджета; многопанельный конструктор относится к **Start**.

Код: [`src/qml/HomeDashboard.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/HomeDashboard.qml), [`src/features/home/HomeDashboardController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/home/HomeDashboardController.cpp#L32-L100), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L725-L749).

## Глобальные боковые панели

| Вызов | Содержимое | Действия |
| --- | --- | --- |
| **X → Quick Apps** | Избранные закреплённые приложения + запущенные приложения, индикатор работы | Быстрый переход; удержание → опции приложения; список запущенных прокручивается |
| **Y → Recent / ★** | «Recent games» и «★ Favorites», переключение L2/R2 | Открыть выбранную игру, сохранить выбор и прокрутку |
| **Колокольчик / сочетание Home** | Уведомления и входящие звонки | Открыть, удалить, очистить, принять/отклонить звонок |

Код: [`src/qml/QuickAppsDrawer.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/QuickAppsDrawer.qml), [`src/qml/AppsDock.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/AppsDock.qml), [`src/qml/ContinueDrawer.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/ContinueDrawer.qml), [`src/qml/NotificationPopover.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/NotificationPopover.qml).

## Start — системная панель, а не Home

Вызов **Start** открывает **ControlsPanel**, то есть отдельную системную панель с действиями **Settings / Power / Switch** и настраиваемой сеткой быстрых виджетов.

- Виджеты по умолчанию: **Volume, Brightness, Wi-Fi, Bluetooth, Airplane, Downloads, Battery, Clock, Storage, ScreenScraper**; возможны внешние SDK-виджеты.
- **Edit widgets**: добавление обратно скрытых, скрытие, перемещение, смена размеров, несколько страниц (в модели до восьми), конфигурация сохранена для текущего владельца.
- **Sound** из виджета Volume: вкладки Sources, Microphones, Output device; уровни и mute там, где контроллер аудио отмечает доступность.
- **Wi-Fi/Bluetooth** открывают отдельную панель соединений. Воздушный режим и яркость — быстрые действия.
- **Switch** предлагает Desktop / Steam Gaming Mode; доступность зависит от платформы и состояния запущенной игры/приложений.
- **Power**: Sleep, Keep awake, Restart, Power off и условное действие входа в режим TrainerOS из development environment. При активной игре сон заблокирован кодом как не проверенный; это **не** suspend/resume игры.

Код: [`src/qml/ControlsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/ControlsPanel.qml), [`src/features/device/ControlsDashboard.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/device/ControlsDashboard.cpp#L15-L38), [`src/features/device/ControlsDashboard.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/device/ControlsDashboard.cpp#L168-L197), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L1350-L1359), [`src/app/Main.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/app/Main.cpp#L735-L750).

## Профиль игрока — отдельное окно

Вход через верхнее имя/аватар (а не через постоянную вкладку). Реализована компоновка: редактирование локального/связанного профиля, внешний вид/wardrobe и scenery, **Level / XP**, **Sparks**, trophy shelf, recent achievements, last adventure, **Player journey**, **Screens**, **RetroAchievements**, **Account & rewards**, действия поддержки, магазин и приватность/видимость профиля. Поддержка, магазин и награды зависят от входа и серверных ответов: наличие экранов не доказывает готовность финансовых или наградных сценариев.

Код: [`src/qml/PlayerProfilePanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/PlayerProfilePanel.qml), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L1806-L1921).

## Game Options — во время игры

Это отдельная внутриигровая панель, а **не** ещё одна системная вкладка. Видимые базовые действия: **Continue**, **Minimize**, **Exit game**; дополнительные команды подставляются runtime/игрой (настройки, достижения, взаимодействия с участниками при соответствующих условиях). При завершении используются отдельные процессы обработки выхода/сохранений. Меню не означает универсальную паузу, savestate или гарантированное восстановление сна.

Код: [`src/qml/GameActivity.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/GameActivity.qml), [`src/qml/GameOptions.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/GameOptions.qml), [`src/features/adventure/AdventureExitPresentation.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/adventure/AdventureExitPresentation.cpp#L31-L56), [`src/app/Main.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/app/Main.cpp#L763-L774).

## Что отдельно перепроверить перед альфой

- Профиль, значки, Sparks, виджеты и уведомления на **чистой учётной записи** и без интернет-соединения.
- Реальный переход по Home, L1/R1, L2/R2, X/Y, Start и Back на контроллере и касанием; возврат фокуса из полноэкранного браузера/модалки.
- Запуск и сворачивание игры, возврат и выход на целевом устройстве; зависшие процессы.
- Start → Desktop/Steam с открытыми приложениями и сохранением состояния, проверка запретов; **не выполнять небезопасный физический sleep test без отдельного решения владельца**.
- Отдельное качество UX: видимость кнопок на 800×450 / 960×540 / TV масштабах и доступность без контроллера.
