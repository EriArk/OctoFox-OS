# Crates — функциональный аудит каталога и менеджера пакетов

**Дата среза:** 2026-11-03. **TrainerOS main:** `6d394850d23c46fe610446f0d202315db25295a5`. **EriArk/crates main:** `fea662d59d30026ebb72546dad9a20631cc7ff0f`. Метод: исходники C++/QML/Python + датированные тестовые отчёты и публикационные записи. **В этом проходе ничего не устанавливалось, не запускалось на устройствах и не тестировалось физически.** Ранее задокументированные физические проверки указаны отдельно.

## 1. Что такое Crates в системе сейчас

**Crates = каталог + подписанные сведения о версиях + очередь Downloads + единый установщик и реестр пакетов + запуск через стандартные Games/Apps.** Он находится в **Online → Crates**, а не во вложенной полосе Apps. Игры из пакетов добавляются в Games, приложения — в Apps; некоторые приложения публикуют виджеты в Start или Home посредством Platform SDK. Это **не** целый отдельный лаунчер игр и не Bazaar.

- Точка входа: [ShellController / Online face](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/core/navigation/ShellController.cpp), [Main / CratesPage](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/Main.qml).
- Экран и обработчики: [CratesPage](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesPage.qml), [CratesCataloguePage](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesCataloguePage.qml), [CratesProjectPopup](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesProjectPopup.qml), [CratesController](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesController.cpp).
- Внешний каталог исходных проектов: [EriArk/crates](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f).

### Полное дерево видимых экранов

```text
Online
└── Crates
    ├── What's New                ← крупный ящик
    ├── Workshop                  ← крупный ящик
    ├── Adventure                 ← тематический ящик (пуст в bundled snapshot)
    ├── Arcade
    ├── Strategy
    └── Tools & Modules
         └── [Список проектов, до 6 на странице, 3 × 2]
               └── [Карточка проекта]
                   ├── artwork / screenshots / автор / описание / лицензия
                   ├── версия / архитектура / compatibility / размер
                   ├── Download | Update | Play/Open | View progress
                   └── Remove (только после установки)
                         └── подтверждение, исходно Cancel
    └── Update all (если есть обновления)
         └── подтверждение, если совместимость не supported
```

Источники названий и порядка: [showcase.json](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/data/crates/showcase.json). Переходы/пагинация/фокус: [CratesController](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesController.cpp). Видимое 3×2: [CratesCataloguePage](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesCataloguePage.qml).

| Зона | Данные, которые видит игрок | Действие / результат в исходниках |
| --- | --- | --- |
| Корневые ящики | 2 крупных (What's New, Workshop), 4 тематических | A/touch открыть; анимация открытия, reduced motion учитывается |
| Список проектов | Обложка, название, краткие признаки, страницы по 6 | Выбрать A, листать, Back к ящикам |
| Карточка проекта | Изображения, описания, автор, лицензия, статус версии/архитектуры/совместимости | Primary, удаление/подтверждение, переключение скриншотов |
| Верхняя команда | Update all · N при доступных обновлениях | Очередь обновлений с подтверждением для непроверенных пакетов |
| Общий Downloads | Состояние задачи, прогресс, пауза/возобновление, отмена, повтор, перестановка очереди | Ничего не устанавливается просто от просмотра каталога |

## 2. Точные состояния основной кнопки

Приоритет в `CratesController::primaryLabel()`:

| Условие | Надпись | Что делает primary |
| --- | --- | --- |
| Для выбранного проекта есть активная операция | **View progress** | Открывает общий Downloads |
| Установлен пакет и найдена новая версия | **Update** | Запрашивает установку нового релиза; неподтверждённый — через предупреждение |
| Пакет установлен; свежего обновления нет | **Play** (game) / **Open** (app/module) | Игра → штатный Games launch; приложение → обычный Apps, либо Home contribution |
| Каталог недоступен и пакет не установлен | **Connect to download** | Скачивание недоступно |
| Есть допустимый пакет для архитектуры | **Download** | Очередь установки; `untested` требует явного согласия |
| Нет доступной пакетной записи | **Package coming soon** | Нет установки: карточка может быть только описанием |

**Версии вручную больше не выбираются** в обычном UX: прежние разделы `Versions` в исторических отчётах относятся к старому интерфейсу. Источники: [CratesController lines 125–189](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesController.cpp), [Crates76 — актуальный UX](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/CRATES76_INSTALLER.md).

При установленном пакете справа от primary есть **красная корзина**, которая открывает `Remove this project?` с предупреждением `Your saves and data will be kept`; исходный вариант — Cancel, B закрывает окно. При активной операции Remove блокируется. Непроверенная установка имеет **другое** подтверждение `Install anyway?`. Код: [CratesProjectPopup](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesProjectPopup.qml), [контроллер](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesController.cpp).

## 3. Где живёт пакет после установки

| Тип записи | Где виден | Обработчик | Важная граница |
| --- | --- | --- | --- |
| `game` | Games, регистрация `crates:<id>` | CratesLibrary → AdventureLaunchController, Game Options, checkpoint/history | Не любой SDK-game автоматически имеет RA/сохранения как ROM |
| `app` | Apps, Desktop Entry `org.traineros.crates.<id>.desktop` | Общий app launcher, окна/Quick Apps | Пакету нужен рабочий runtime и управление фокусом |
| `app` с Home contribution | Home widget picker, кнопка Open может выбрать виджет | Проверенная `home-widgets.json` + host renderer | Установка сама **не заменяет** пользовательский виджет |
| Приложение с `ui.start.widget` | Start → Edit → Add после запуска процесса | SDK connection, callback, lifecycle | Нет автоматического запуска widget-провайдера |
| `module` | Допустимое поле модели/изображение в карточке | Пакетный schema/parser допускает тип | **Нет доказательства общего работающего system-module SPI и загружаемых модулей** |

Реальный маршрут: [Main / связка Crates → Library, Apps, Home](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/app/Main.cpp), [CratesLibrary](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesLibrary.h), [AppsController](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/apps/AppsController.cpp), [Home widget API](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/sdk/HOME_WIDGETS.md), [Platform SDK v1](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/sdk/README.md).

**Особенность:** `CratesController::launchRequested` сначала проверяет, можно ли выбрать `Home`-вклад через `dashboard.selectPackageWidget(id)`; затем game направляется в `launchPreparation().launch("crates:"+id)`, прочее — в Desktop Entry. Это не означает, что тип `module` имеет собственный изолированный lifecycle.

## 4. Подписанный каталог, offline и обновления

- Локальный встроенный каталог `data/crates/catalogue.json` служит **витриной**, может иметь проекты без единого релиза; он не даёт возможности установки сам по себе.
- Отдельный Python-клиент получает подписанный snapshot/delta, проверяет **Ed25519**, schema, размеры, хеши, каноническое состояние и атомарно заменяет кеш. При offline/сбое остаётся предыдущий подтверждённый каталог; уже установленное ПО можно запускать.
- Сервер отдаёт метаданные и небольшие изображения, **не** исполняемые зеркала. Разрешённые архивы — точные GitHub Release assets из `EriArk/TrainerOS` и `EriArk/crates`; необходимы URL, размер и SHA-256.
- Worker распаковывает в ограниченный staging, публикует immutable content-addressed объект и `active/<id>.json` receipt. Транзакционный журнал позволяет восстановить прерывание; старый код и пользовательские `data/<id>` сохраняются.
- Удаление убирает исполняемый объект/регистрацию, **не** удаляет отдельные пользовательские данные и историю Games. Переустановка восстанавливает прежнюю `crates:<id>` запись.
- Запущенные/minimized приложения блокируют замену через lease/`flock`; пока идёт активная игра или save-операция, guard удерживает работу.
- Общее Downloads хранит операции и паузы. Поддерживаются Continue/Retry и проверенное возобновление частичных HTTP Range загрузок, не произвольная запись поверх архива.

Источники: [package/verification/recovery contract](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/README.md), [catalogue.py](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/catalogue.py), [installer.py](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/installer.py), [CratesInstaller](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesInstaller.cpp), [проверки recovery 26.10](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/crates-recovery-20261026/README.md).

### Автоматические обновления

Точка: **Start → Settings → Installed software → Automatic Crates updates**. По умолчанию **Off**; при включении проверяет сразу, далее примерно раз в **15 минут**, после перезапуска — спустя **30 секунд**. Работает **только с уже установленными пакетами**, у которых следующая запись имеет статус совместимости `supported`. Это не подписка на любое обновление и не принудительное автообновление всех `untested` игр. При pause/cancel/failure та же версия не повторяется без участия игрока. Скачивание и установка по одной общей очереди, с ограничением на занятые игры.

Manual `Update all` отдельно может затребовать согласие на `untested` пакет. Это не гарантия установки пакета другой архитектуры.

Код: [automaticCheck/confirmUpdates](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesController.cpp), [queueAutomaticUpdates](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesInstaller.cpp), [Software options](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/settings/SettingsController.cpp), [тестовая и физическая приёмка 26.10](../../evidence/crates-updates-20261026/README.md).

## 5. Доказательства готовности (даты, а не общие впечатления)

| Дата | Что реально подтверждалось | Чего это НЕ доказывает |
| --- | --- | --- |
| 18.10 | Odin/Flip: установка 2048 и FeatherPad, открытие, удаление и восстановление состояния 2048 | Все устройства, весь каталог, все контроллеры |
| 21–22.10 | Авторские Timer, Artillery, 9 аркад; опубликованные пакеты и обновление 4 игр 0.1.0→0.1.1 на Odin/Flip; сохранение history/data | Полноценные онлайн-матчи, физические кнопки, все 9 игр |
| 26.10 | Новый UX Update/Remove/Auto Update, ARM тесты; production shell на Flip/Odin, реальный просмотр настроек | **Не** обновление нового опубликованного релиза автоматикой; **не** контроллер/тач-приёмка |
| 26.10 | SIGKILL/recovery и lease, сохранение очереди, повторная установка на фикстурах; доставка хелперов | Физическая потеря питания в середине транзакции |
| 02.11 | Companion 0.1.0/0.1.1 опубликован; финальная общая поставка host/Companion 0.1.1 на Flip/Odin по `FEATURE_READINESS` | Не все будущие анимации, FPS/батарея, новая реальная награда |
| 03.11 | **Подписанный каталог 43**: 18 проектов, 81 release record; изменились только публичные названия/описания «Alpha Preview» | Не было новых физических установок; байты, совместимость и версии пакетов **не менялись** |

Ссылки: [Crates76](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/CRATES76_INSTALLER.md), [Crates77](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/CRATES77_CATALOGUE.md), [26 октября](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/crates-updates-20261026/README.md), [Companion delivery](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/2026-11-02-profile-polish/README.md), [FEATURE_READINESS](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/FEATURE_READINESS.md), [публичная ревизия 43](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/2026-11-03-crates-alpha-preview/publication.json).

## 6. Выявленные риски и несоответствия

1. **Bundled ≠ signed server.** Bundled `main` — **17** проектов с пустыми release-списками; публичный каталог 43 — **18**. Дополнительная запись — **Micro Rally**, отсутствующая в локальной витрине main. Новые/прошлые релизы сервер может показывать независимо от встроенного snapshot.
2. **Micro Rally:** в `EriArk/crates` / `games/competitive-minigames/micro-rally` текущий `main` содержит **только README/idea**, но в GitHub Releases есть **micro-rally-v0.1.3** (29.10). Перед объявлением исходники и точное соответствие пакета проверить по source archive/tags/release record, а не по содержимому директории main.
3. **Реальное несовпадение предупреждения:** `requestPackage()` требует согласие и для `untested`, и для `incompatible` на подходящей архитектуре, но UI-строка и кнопка говорят `Install anyway · untested` / `This release is not tested on your device` в обоих случаях. Для `incompatible` должно быть явно обозначено **несовместимо**, либо установка должна блокироваться. Проверить как дефект UX/безопасности перед релизом. [requestPackage](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesController.cpp), [confirmation UI](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesProjectPopup.qml).
4. **Свежий Live catalogue не меняет бинарники**: фраза `Alpha Preview` — метка публикации, а не `Stable/Beta/Experimental` channel или акт физической проверки.
5. **System modules / plugins:** parser знает `module`, но система не обещает загрузку нативных расширений/произвольного QML; текущий SDK поддерживает ограниченные декларированные сервисы. Не писать «Crates поддерживает полноценные модули» без отдельного SPI-аудита.
6. **Session Timer:** на портативках собственная `Back to TrainerOS`/Qt minimize не возвращала фокус; рекомендован системный `Home → Minimize`. Нет автозапуска Start-widget. [исходный проект Timer](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/widgets/session-timer/README.md).
7. **Companion** — пакет ассетов/деклараций, но жизненный цикл 3D и логика питомца принадлежат **host TrainerOS**. Старый shell после обновления только Crates-пакета не получает новую графику/поведение. [host contract](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/sdk/HOME_WIDGETS.md).
8. **Не все 24 мини-игры реализованы:** в репозитории девять полноценнее разработанных игр, остальные пока идеи. Аналогично большинство Widgets/Apps/Extensions — текстовые замыслы, не готовые модули.
9. **Не тестировались в этом проходе:** установка всех 18 проектов на чистом Setup, ARM+PC в итоговом альфа-кандидате, контроллер/тач каждой игры, отключение интернета/обрыв во время реальной установки и длительная надёжность автообновления.

## Файлы следующего уровня

- [Проекты, публикуемые пакеты и реальные проверки](CRATES_PROJECTS.md)
- [Идеи и ещё не реализованные категории в EriArk/crates](CRATES_CONCEPTS.md)
- [Приёмка Crates для альфа-релиза](CRATES_ACCEPTANCE.md)
- [Краткое пользовательское описание блока](../blocks/CRATES.md)

**Мультиплеер** здесь зафиксирован только как граница интеграции; поддержка режимов, P2P/relay и успешные сетевые игры будут проверяться в **отдельном аудите**.
