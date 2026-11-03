# Реестр проектов Crates: витрина, код, релизы и проверка

**Срез 2026-11-03.** Два независимых источника: встроенный [bundled catalogue](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/data/crates/catalogue.json) (`main` 6d394850d23c46fe610446f0d202315db25295a5) и опубликованная [подписанная ревизия 43](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/2026-11-03-crates-alpha-preview/publication.json) (18 проектов, **81 историческая запись релиза/архитектуры**, не 81 уникальная игра). `EriArk/crates` `main` — fea662d59d30026ebb72546dad9a20631cc7ff0f. **В этом аудите пакеты не скачивались и не запускались.**

## Текущий набор подписанного каталога — 18 названий

Пометка `(Alpha Preview)` — часть текущих пользовательских названий всех 18 проектов, не отдельный channel и не результат теста.

| ID | Отображаемое имя (без общего суффикса) | Тип | Где находится реализация / источник | Что можно обоснованно утверждать |
| --- | --- | --- | --- | --- |
| `2048` | 2048 | game | [рецепт TrainerOS](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/recipes/2048.json); внешний MIT upstream | Экспериментальный webgame-пакет; 18.10 открывался на Odin/Flip, локальный счёт сохранился |
| `hextris` | Hextris | game | [рецепт](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/recipes/hextris.json); внешний upstream | В подписанном каталоге; конкретный свежий physical launch не подтверждён здесь |
| `breakout` | Breakout | game | [рецепт](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/recipes/breakout.json); webgame runner | В подписанном каталоге, отдельные звуковые и сетевые ограничения порта; physical launch OPEN |
| `featherpad` | FeatherPad | app | [рецепт](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/recipes/featherpad.json); внешний upstream | Экспериментальный установленный/открытый app на Odin/Flip (18.10) |
| `qalculate` | Qalculate! | app | [рецепт](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/recipes/qalculate.json); внешний upstream | Пакет/зависимости подготовлены; конкретный physical acceptance OPEN |
| `session-timer` | Session Timer | app + Start widget | [внешний проект](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/widgets/session-timer/README.md) | Опубликован; на Flip/Odin открывался с SDK, Start-widget работал на Flip, физические кнопки и Back issue |
| `pocket-artillery` | Pocket Artillery | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/pocket-artillery/README.md) | Реальные опубликованные 0.1.x; базовый gameplay проверялся, полноценный сетевой матч OPEN |
| `pong` | Pong | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/pong/README.md) | Пакеты опубликованы; запуск с ботом проверялся на Odin |
| `snake-arena` | Snake Arena | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/snake-arena/README.md) | Пакеты опубликованы; запуск с ботом проверялся на Odin |
| `light-cycles` | Light Cycles | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/light-cycles/README.md) | Пакеты опубликованы; результат партии проверялся на Flip |
| `falling-blocks` | Falling Blocks | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/falling-blocks/README.md) | Пакеты опубликованы; код правил/UI есть, подробная физическая приёмка OPEN |
| `minesweeper-race` | Minesweeper Race | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/minesweeper-race/README.md) | Пакеты опубликованы; код правил/UI есть, подробная физическая приёмка OPEN |
| `chain-reaction` | Chain Reaction | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/chain-reaction/README.md) | Пакеты опубликованы; код правил/UI есть, подробная физическая приёмка OPEN |
| `mini-racing` | Brick Racing | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/mini-racing/README.md) | Пакеты опубликованы; на Flip проверялась практика с ботом и выход |
| `tanks` | Brick Tanks | game | [исходники](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/tanks/README.md) | Пакеты опубликованы; на Flip проверялась практика с ботом и выход |
| `pocket-golf` | Pocket Golf | game | [исходники Godot](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/pocket-golf/README.md) | 3 поля, соло/локальный режим, SDK/аватар; опубликован в нескольких версиях, ограниченная физическая проверка |
| `micro-rally` | Micro Rally | game | [main: идея/README](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames/micro-rally/README.md); [GitHub Release 0.1.3](https://github.com/EriArk/crates/releases/tag/micro-rally-v0.1.3) | **Есть опубликованный архив, но в main-папке проекта нет игрового кода**; проверять release source archive и фактическое выполнение отдельно |
| `home-companion` | Companion | app + Home widget | [проект](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/widgets/home-companion/README.md) + [host SDK](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/sdk/HOME_WIDGETS.md) | Опубликованы 0.1.0 и 0.1.1; установлен и проверен в общей поставке Flip/Odin 02.11; производительность/батарея OPEN |

**Итого по 18 позициям:** 14 игровых проектов, 4 приложения, **0 отдельно подтверждённых исполняемых system-module пакетов**. Виджет — интеграция установленного `app`, а не четвёртый `kind`.

Доказательства устройств/дат: [Crates76](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/CRATES76_INSTALLER.md), [Crates77](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/CRATES77_CATALOGUE.md), [2.11 Companion delivery](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/FEATURE_READINESS.md), [Companion / Flip / Odin](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/2026-11-02-profile-polish/README.md). Реальные GitHub Releases: [EriArk/crates releases](https://github.com/EriArk/crates/releases); sample recipes могут загружаться из [TrainerOS Releases](https://github.com/EriArk/TrainerOS/releases).

## Встроенный список vs сетевой

| Уровень | Что известно | Почему нельзя смешивать |
| --- | --- | --- |
| Bundled snapshot `data/crates/catalogue.json` | **17** проектов, `releases: []` во всех встроенных карточках, включая пять `sample:true`; 6 контейнеров | Это offline-витрина; сама не обещает Download |
| Подписанная публикация rev 43 | **18** проектов, **81** package records, единый суффикс Alpha Preview | Сетевой источник может добавлять/отзывать пакеты и версии; публикация от 03.11 изменила только текст |
| GitHub Releases | Фактически опубликованные архивы/исходники под тегами, в том числе Micro Rally 0.1.3 | Публикация тега не является проверкой устройства и не означает наличие кода в `main` |
| Реальная установка | `active/<id>.json` + кодовый объект + профильные данные | Требует отдельного test receipt, архива, архитектуры, конкретного устройства |

### Раскладка шести витрин в bundled snapshot

| Ящик | ID | Количество записей | Особенности |
| --- | --- | ---: | --- |
| What's New | `whats-new` | 17 | Полный локальный набор |
| Workshop | `workshop` | 12 | Авторские проекты (Companion, Golf, 9 аркад, Timer) |
| Adventure | `adventure` | 0 | Намеренно пустой |
| Arcade | `arcade` | 10 | Смешаны опубликованные авторские и сторонние игры |
| Strategy | `strategy` | 5 | Головоломки и Artillery |
| Tools & Modules | `tools` | 4 | Companion, Timer, FeatherPad, Qalculate! |

Из [showcase.json](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/data/crates/showcase.json) и [catalogue.json](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/data/crates/catalogue.json). Один проект может показываться **в нескольких ящиках**, без дублирования package ID.

## Что не следует писать в релизе

- «В Crates уже есть 24 готовые мини-игры» — нет: 24 идеи, 9 игровых реализаций в competitive-minigames + отдельный Pocket Golf; Micro Rally имеет публиковавшийся внешний релиз, но в main ещё лишь README/idea.
- «81 игра» — нет: это **записи версий/архитектур** разных релизов, не количество независимых игр.
- «18 игр» — нет: **18 проектов**, в том числе 4 приложения.
- «Все поддерживаются и работают на любой консоли» — нет: `Experimental` / `untested` и точные платформенные проверки отдельно.
- «Виджет устанавливается и автоматически появляется на Home/Start» — нет: выбор и/или запуск остаются явными действиями.
- «Alpha Preview — новый канал/версия» — нет: только отображаемое имя и начало описания.
- «Crates — самостоятельная серверная игровая сеть» — нет: social и multiplayer используют другие общие сервисы.
