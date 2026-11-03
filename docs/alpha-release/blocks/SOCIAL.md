# Online и Social: вкладки, переписки, сообщества и Discover

**Проверка:** `CODE` — навигация, QML и обработчики `main` bb3d242530753fd956526b793e273d4e74adb02f, 2026-11-03. Это **не** аудит качества сети, сервера Fluxer или мультиплеера.

## Online — верхний уровень

| Вложенная вкладка | Что реализовано в UI | Граница / статус |
| --- | --- | --- |
| **Lobby** | Точка входа в лобби; интерфейс использует SocialPage и связанные диалоги | **Отдельный аудит мультиплеера**; список проверенных игр здесь не обсуждается |
| **Bazaar** | Информационный экран с текстом «A place to meet, explore and trade» | **Заглушка.** Миры и комнаты игроков прямо помечены недоступными |
| **Crates** | Каталог/вход в отдельную страницу Crates | **Отдельный аудит Crates** (установка, каталоги, пакеты, интеграции) |
| **Chats** | Контейнер Messages / Communities / Discover | По UI проверено ниже, сеть не тестировалась |

Код: [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L892-L908), [`src/qml/OnlinePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/OnlinePage.qml).

## Chats — три вложенных раздела

| Раздел | Содержимое | Действия и переходы |
| --- | --- | --- |
| **Messages** | Список людей/диалогов слева, активная беседа справа | Открыть чат, профиль собеседника, написать/отправить текст, вызвать контекстное меню, прикрепить файл/эмодзи, совершить вызов при доступности |
| **Communities** | Список групп/сообществ и их каналов, выбранная переписка | Перейти в канал, открыть информацию/настройки и варианты создания/управления по уровню разрешений |
| **Discover** | Поиск **People / Communities**, блок **Recently together**, результаты и предварительный просмотр | Искать, просматривать участников/группы, открывать профиль, переходить по действиям поиска |

Доступен вход в Fluxer через код/авторизацию, экран подключения и статус. При отсутствии входа вместо чатов показывается onboarding/login; отдельные действия/доступ к данным зависят от учётной записи и прав участника.

Код: [`src/qml/SocialPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SocialPage.qml), [`src/qml/OnlinePage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/OnlinePage.qml#L8-L36), [`src/qml/DiscoverPane.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/DiscoverPane.qml).

## Внутри переписки

Панель `ConversationPane` содержит:
- заголовок диалога/имя, вызов и меню действий;
- историю сообщений, загрузку более ранних и переход к последним;
- сообщения с прикреплёнными файлами и состоянием доставки, возможность retry при ошибке;
- composer: текст, вложения, emoji, голосовое сообщение / диктофон при доступности; отправка;
- при активном разговоре — полосу вызова с mute, deaf и завершением.

**Это подтверждение UI и обработчиков**, а не принятой скорости/надёжности отправки вложений, аудио, звонков или всех типов групп. Функции voice call и потокового просмотра зависят от отдельных сервисов и требуют собственных проверок.

Код: [`src/qml/ConversationPane.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/ConversationPane.qml), [`src/qml/SocialPage.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/SocialPage.qml#L119-L193).

## Связи с другими поверхностями

- **Home** показывает людей и кнопку Create/My Lobbies; нажатие на друга открывает беседу.
- **Уведомления** используются для новых событий/входящих звонков, а не являются разделом Chats.
- **Профиль игрока** включает privacy/visitor/public profile, а также действия контакта; это отдельное окно.
- **Game Options / Lobby** могут показывать участников и вызовы, но **анализ мультиплеера и голосовой подсистемы ещё впереди**.

Код: [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L725-L749), [`src/qml/NotificationPopover.qml`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/qml/NotificationPopover.qml), [`src/core/navigation/ShellController.cpp`](https://github.com/EriArk/TrainerOS/blob/bb3d242530753fd956526b793e273d4e74adb02f/src/core/navigation/ShellController.cpp#L1837-L1855).

## Статус альфы

- **UI CODE:** присутствуют маршруты, отображение данных, компоненты и вызовы контроллеров.
- **Physical TESTED:** эта ревизия специально не прогонялась. Датированная [частная проверка](../../PREBETA_RELEASE_RU.md) фиксирует успешный вход чатов Fluxer на Flip после исправления discovery и восстановление сессии; это **не** проверка всех чатовых функций.
- **Нельзя обещать:** универсальное мультиплеерное подключение, подтверждённую работу любого голосового вызова/вложения, полный функционал Bazaar, готовность независимых Crates-проектов.
