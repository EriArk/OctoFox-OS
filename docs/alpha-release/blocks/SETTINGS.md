# Settings — полная карта категорий и подразделов

**Проверка:** `CODE` из `SettingsController.cpp` / `SettingsPanel.qml` на `main` bb3d242530753fd956526b793e273d4e74adb02f, 2026-11-03. **Не означает аппаратную приёмку**.

В Settings шесть основных категорий. Справа — динамические внутренние страницы; часто `L2/R2` переключает их. Некоторые строки скрыты или недоступны при отсутствии оборудования/аккаунта.

| Главная категория | Вложенные страницы | Реальные поля / действия | Что не обещать |
| --- | --- | --- | --- |
| **Personalization** | **Appearance**, **Media** | Светлая/тёмная тема; reduced motion; яркость; профили TV/Handheld/Auto; масштаб интерфейса и сброс; локальные video previews, звук/задержка preview, отображение иллюстраций | Не все media-поля самостоятельные переключатели |
| **Device** | **Audio**, **Controller**, **Game input**, **Connections**, **Feedback** | Громкость; громкость сигнала достижения; тип и символы контроллера, confirm, deadzone, инверсия осей, сброс/калибровка; индивидуальные игровые назначения ввода; Wi-Fi/Bluetooth; сведения о совместимости | **Background music** недоступна; **зарядная вибрация/подсветка** не проверены |
| **Accounts & communication** | **Trainer**, **Communication**, **Nearby** | Локальный профиль и связанные учётные записи, RetroAchievements, переключение/создание Trainers и PIN (если функция разрешена), коммуникации/аккаунт, видимость для соседних игроков | Не все действия доступны без входа; наличие PIN-строки ≠ поддержка на всех установках |
| **Games & library** | **Library**, **Saves**, **Scraper**, **Online services** | Коллекции, ручной/автоматический scan, пути Game storage, ScreenScraper, Game preparation; read-only policy saves; настройка Online для Wii/3DS/Wii U | Настройка сервиса/«prepared» не доказывает вход/игровую совместимость |
| **Installed software** | **Software** | Перейти к Apps/Crates, переключить автоматические обновления Crates | Подробности Crates — отдельный аудит |
| **System** | **System**, **Clock**, **Credits** | Refresh status, Restart, Power off, Health & game setup, Updates; часы/время; данные о проекте/лицензии | Возможности ОС и обновлений проверять на конкретной сборке |

Источник дерева страниц: [`src/features/settings/SettingsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/settings/SettingsController.cpp#L18-L35). Реальные строки и условия: [`src/features/settings/SettingsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/settings/SettingsController.cpp#L126-L198). Визуальная структура: [`src/qml/SettingsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SettingsPanel.qml).

## Существенные детали и условные состояния

- **Appearance**: цветовая тема; reduced motion; яркость; display profile (`auto/handheld/tv`); interface scale от **75% до 150%** (шаг изменения через контроллер), сброс к 100%.
- **Audio**: глобальная громкость и Achievement jingle с уровнем 0–100%; строка «Background music» прямо `unavailable`.
- **Controller**: настройки профиля доступны при соединённом контроллере; адаптация символов под семейство устройства; отдельная настройка **Game input** для игр.
- **Library**: Scan now только при готовом библиотечном источнике; storage и ScreenScraper ведут в отдельные панели; показ старой корзины **условный**; Game preparation содержит обработчик перехода.
- **Saves**: переключатель read-only зависит от наличия `savePolicy`; не обещать обратную запись сейвов для всех платформ.
- **Online services**: список Console, Online service, Set up Online, Preparation confirmed, Check Online setup. Контроллер сам поясняет, что файлы могут быть подготовлены, но вход в сервис ещё **не проверен**.
- **Software**: автоматические обновления Crates могут ждать, пока пользователь закончит игру; это пункт управления, не результат проверки любой установки.
- **System**: UpdatesPane отдельный от меню; запрошенная перезагрузка/выключение проходит через системную интеграцию, а не сам QML.

Код: [`src/features/settings/SettingsController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/features/settings/SettingsController.cpp#L126-L253), [`src/qml/GamePreparationPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/GamePreparationPanel.qml), [`src/qml/SettingsPanel.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SettingsPanel.qml).

## Минимальный список физической приёмки

1. Переключить каждую категорию, выполнить Back, проверить фокус и scroll на 960×540/800×450.
2. Изменить тему/масштаб/вид Preview; закрыть и перезапустить оболочку, проверить сохранение.
3. Проверить настройки контроллера на настоящем устройстве и восстановление стандартного профиля.
4. Проверить реальные Wi-Fi/Bluetooth, audio output и уровень звука без сброса личной сети.
5. Проверить сканирование библиотеки, привязку пути microSD и безопасную работу ScreenScraper.
6. Явно зафиксировать `unavailable`-строки и пункты, зависящие от подключённых аккаунтов.
