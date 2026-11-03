# Apps, Browser, Files и Quick Apps

**Проверка:** `CODE` — реализация UI/контроллеров `main` bb3d242530753fd956526b793e273d4e74adb02f, 2026-11-03; запуск конкретных внешних приложений **OPEN**.

## Вкладка Apps

У неё **три вложенных раздела: Apps, Browser, Files**. Crates в текущей навигации расположен в **Online**, а не здесь.

### Apps — сетка приложений

Пятиколоночная сетка найденных приложений: иконка, название, выделение; запуск касанием или A. Удержание вызывает контекстное меню. Controller хранит избранные и скрытые приложения, предоставляет отдельный список скрытых и фиксирует текущие запущенные процессы. Пользовательские предпочтения сохраняются отдельно для выбранного профиля.

**Пункты меню приложения:** Add/Remove favorite, Hide/Show in Apps, Hidden applications/All applications, Back. Для запущенного приложения предусмотрены возврат, минимизация и закрытие (когда app helper поддерживает команду).

Код: [`src/qml/AppsPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/AppsPage.qml), [`src/features/apps/AppsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/apps/AppsController.cpp#L117-L145), [`src/features/apps/AppsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/apps/AppsController.cpp#L183-L230).

### Browser — встроенный браузер

По реализации предусмотрены: стартовая страница/быстрые ссылки, строка поиска или адреса, Back/Forward, список вкладок и создание/закрытие вкладок, **Bookmarks**, **History**, управление страницей с контроллера/указателем, запросы сайта (включая выбор файлов для upload), режим развёрнутого браузера. В QML есть явная заглушка **«This build has no embedded web engine»** для окружений без WebEngine — поэтому наличие Browser не равняется гарантированной работе интернета в любой сборке. Не делать публичное обещание полного совместимого web browsing без проверки.

Код: [`src/qml/BrowserPane.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/BrowserPane.qml); активная геометрия/разворачивание из [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L333-L351).

### Files — файловый менеджер

Реальная экранная компоновка: **breadcrumbs** текущего пути, боковой список **places**, сетка **files/folders**, значки выбора и контекстное управление (A открыть, удержание — действия, Select — Controls, R3 — View). Служба файлов отделена от QML; сценарии копирования/перемещения/права/диалоги нужно независимо проверить на обычном накопителе и microSD.

Код: [`src/qml/FilesPane.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/FilesPane.qml), [`src/qml/Main.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/Main.qml#L529-L533).

## Quick Apps — глобальная боковая панель

Вызывается **X**, доступна вне Apps; содержит **закреплённые Favorites** и **текущие Running apps** с визуальной границей и индикатором активности; у запущенных приложений возможна прокрутка. Нажатие запускает/открывает приложение, удержание — контекстное меню. Это не папки по iOS-концепту из будущих решений, а **реальная горизонтальная панель**, как реализовано сейчас.

Код: [`src/qml/QuickAppsDrawer.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/QuickAppsDrawer.qml), [`src/qml/AppsDock.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/AppsDock.qml).

## Ограничения и что проверить физически

- Каталог зависит от установленных приложений и помощника discovery; пользователь может получить пустую страницу.
- UI smoke-тест Apps использует **подставной каталог и не запускает внешний процесс**. [`tests/ui/AppsSmokeScenario.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/tests/ui/AppsSmokeScenario.cpp#L20-L79). Проверки внешних приложений, фокуса, возврата и multi-window — OPEN.
- Наличие и свойства WebEngine для целевой Armada-сборки, доступность сайтов, HTTPS и upload.
- Права Files: локальная библиотека, microSD, системные папки, частично завершённые копирования, безопасная отмена.
- Возврат в TrainerOS при переходе из браузера/приложения и сохранение состояния Quick Apps.
