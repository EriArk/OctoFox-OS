# Crates: какие идеи уже имеют код, а какие ещё нет

**Источник:** git tree `EriArk/crates` `fea662d59d30026ebb72546dad9a20631cc7ff0f`, актуально для 2026-11-03. Дерево файлов проверено: *только README + docs/idea.md* отмечается как `IDEA_ONLY`. Наличие нескольких файлов с правилами/UI — `SOURCE_PRESENT`, но **не** физический test pass. Отдельный опубликованный Micro Rally описан в [реестре релизов](CRATES_PROJECTS.md).

## Соревновательные мини-игры — 24 задумки, 9 source implementations

| Статус в main | Проекты |
| --- | --- |
| **SOURCE_PRESENT (9)** | Pocket Artillery, Pong, Snake Arena, Light Cycles, Falling Blocks, Minesweeper Race, Chain Reaction, Brick Racing (`mini-racing`), Brick Tanks (`tanks`) |
| **IDEA_ONLY (15)** | Arrow Arena, Asteroid Arena, Block Breaker, Bomb Arena, Bubble Duel, Button Wars, Disc Battle, Marble Rush, Micro Rally*, One Hit Arena, Sumo Bots, Territory Wars, Tiny Duel, Tower Climber, Treasure Rush |

\*Micro Rally — **исключение:** в `main` только концепт, но [отдельный опубликованный релиз 0.1.3](https://github.com/EriArk/crates/releases/tag/micro-rally-v0.1.3) существует. Исходники из его release source archive следует сверить с реальным тегом, прежде чем оценивать его по main.

Код/список: [Competitive Mini-Games](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/competitive-minigames). **Отдельно:** Pocket Golf — активный Godot-проект, не входит в эти 24 мини-игры.

## Widgets — 12 каталогов

| Статус | Проект | Что это |
| --- | --- | --- |
| **SOURCE_PRESENT** | [Session Timer](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/widgets/session-timer/README.md) | Настоящее приложение с временным Start widget |
| **SOURCE_PRESENT** | [Home Companion](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/widgets/home-companion/README.md) | Настоящий `app`-пакет с декларативным Home widget |
| **IDEA_ONLY** | Achievement Hunt | Подбор достижений |
| **IDEA_ONLY** | Arcade Today | Сводка/активности |
| **IDEA_ONLY** | Backlog Dice | Случайный выбор игры из очереди |
| **IDEA_ONLY** | Controller Monitor | Контроллеры и их состояние |
| **IDEA_ONLY** | Friend Radar | Игровая активность друзей |
| **IDEA_ONLY** | Game Roulette | Выбор игры |
| **IDEA_ONLY** | Music Radio | Музыка/радио; в main только концепт |
| **IDEA_ONLY** | Quick Notes | Заметки |
| **IDEA_ONLY** | Screenshot Frame | Кадры/изображения |
| **IDEA_ONLY** | Tournament Live | События соревнований |

Итого **2 с кодом + 10 текстовых идей**. Отдельно поддерживается ограниченный SDK API внешних пользовательских Start-виджетов, но этот API **не делает готовым каждый проект из списка**.

[Всё дерево Widgets](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f/widgets).

## Apps — 4 концепта, не готовые пакеты в этом репозитории

Chiptune Studio, Comic Shelf, PixelPad, Pocket Radio — **IDEA_ONLY** (README и файл идеи, без приложения в main). **FeatherPad и Qalculate!** — реальные сторонние пакетные примеры Crates, но исходники/рецепты лежат в **TrainerOS packaging**, а не в `EriArk/crates/apps/`.

[Apps](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f/apps).

## Extensions — 9 концептов, не действующие системные плагины

Audio Profiles, Controller Overlay, Dock Profiles, Ghost Racing, Live Translator, Retro Shader Packs, Save Journal, Tate Mode, Touch Mapper — **IDEA_ONLY**. Каждая директория содержит только README/idea. Идеи **не означают** поддержку загрузки нативных расширений в Alpha.

[Extensions](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f/extensions).

## Game Tools, game shows и общие концепты

| Каталог | Идеи | Статус |
| --- | --- | --- |
| Game Tools | Speedrun Timer | IDEA_ONLY; дополнительные заметки об идеях |
| Game Shows | Audience Game Show | IDEA_ONLY |
| Concepts | Achievement Coins, Clan Battles | IDEA_ONLY; не выпущенные сервисы |
| Core proposals | Идеи для ядра TrainerOS, а не устанавливаемые Crates | PLANNING |

Ссылки: [Game Tools](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f/game-tools), [Game Shows](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f/games/game-shows), [Concepts](https://github.com/EriArk/crates/tree/fea662d59d30026ebb72546dad9a20631cc7ff0f/concepts), [Core proposals](https://github.com/EriArk/crates/blob/fea662d59d30026ebb72546dad9a20631cc7ff0f/docs/traineros-core-proposals.md).

## Разделение маркетинговых обещаний

- `IDEA_ONLY`: нельзя называть имеющейся кнопкой, игрой или возможностью Alpha.
- `SOURCE_PRESENT`: можно сказать «ведётся разработка», но полноценная доступность зависит от пакета, launcher, SDK и устройства.
- `PUBLISHED`: есть конкретный архив/версия; это **ещё не** `DEVICE_TESTED`.
- `DEVICE_TESTED`: указывать какой commit/пакет и на каком устройстве/режиме, **не** обобщать на сетевой play и другие архитектуры.
- Bazaar, Sparks, общий магазин, рейтинги/турниры, поддержку сообществ и Ghost Racing **не включать автоматически в перечень работающих Crates-функций**. Эти функции имеют собственные требования/серверные зависимости.

[Подтверждённые пакеты](CRATES_PROJECTS.md), [функциональный аудит](CRATES_AUDIT.md).
