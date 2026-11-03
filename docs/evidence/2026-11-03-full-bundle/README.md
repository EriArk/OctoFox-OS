# Полный автономный набор: состав и границы проверки

## Артефакт

`TrainerOS-Full-CANDIDATE.tar`, **3 104 686 080 байт**, 128 внешних файлов.
SHA-256: `ef32232bc2c0737aeaabda7cf3a7729b11a32035755dc02d901f92ef91d9e0da`.
Архив собран на сборочной microSD; состав и каждый вложенный артефакт проверены
после записи. [Результат сборки](media-result.json) не является release approval.
Локальная копия архива также сверена с этим SHA-256 после передачи.
Подготовлены [две части для GitHub](parts.json); побайтовая сумма частей
проверена и даёт тот же SHA-256. Публикации не было.

[29 компонентов](components.json) включают 16 сетевых runtime, RetroArch cores,
обычные AppImages и PSP/linked-save/Remote Play/capture helpers. Остальной состав:
[12 Flatpak refs](flatpak-lock.json), [38 wheels](wheelhouse.json),
[замороженные Python-окружения](python-locks.json), Software validation payload,
Setup candidate 3, source/patch recipes и параметры мультиплеера.

Software payload остаётся сборкой `0d6c6552` с отдельным validation-ключом.
Обычный bootstrap Setup сохраняет production trust key. Это сборочный комплект:
для лабораторного Software-теста ключ передавался явно в отдельную установку.
Переподпись и единая публичная установка ещё не подготовлены. Закрытых ключей
в комплекте нет. Существующие исходники приложения не подменяют обязательный
полный corresponding-source/licence register всех эмуляторов.

## Пройдено

- [88 Python-проверок](tests-result.json) на ARM64 Linux: 8 collection/media,
  3 helper inventory, 22 release, 29 channel, 26 installation.
- [Реальный Software-пакет](offline-software.json): prepare, dependency check,
  install, audit, repeat, uninstall с отключённой сетью в закреплённой официальной
  Armada. Тестовые SQLite/first-run/save файлы сохранили свои контрольные суммы.
  Привилегированная session integration в этом тесте не устанавливалась.
- 38 wheels установлены без сети в этой Armada; `pip check` и импорты LiveKit,
  Wormhole, crypto и network modules прошли. Python binary SHA-256
  `ef59e677fa67d883e7f6d2a5aabbb99f1a14dd77dad74ada90d613202843cb80`
  совпал с manifest requirement существующих сетевых runtime.
- [Все 12 Flatpak refs](offline-flatpak.json) импортированы в отдельный каталог
  без сети. Commit IDs совпали. PPSSPP executable SHA-256
  `01eafca876b8bc05ec2e087f6619bd127d5f6cfbc68aff804b6d362f5fdc25d5`
  совпал с текущей multiplayer allowlist.

## Ограничения, которые не следует скрывать

Контейнер запрещает вложенные bubblewrap namespaces: post-install sandbox steps
печатали `Operation not permitted`. Поэтому результат Flatpak — импорт и проверка
идентичности артефактов, **не** безошибочный запуск установленных приложений.
Обычная проверка namespace и вариант с разрешённым seccomp подтвердили ограничение
контейнерной среды; host sandbox не менялся.

Полный медиапакет не активировался на личных профилях. ОС, загрузочный выбор,
сессии, ROM, firmware, сохранения и аккаунты портативок не мигрировали.
Физическая игра, звук/голос, отдельные внешние сети и общий recovery всего набора
остаются открытыми. [Обязательный следующий цикл](../../FULL_BUNDLE_RU.md#оставшийся-обязательный-цикл)
содержит установку всех компонентов, ownership, миграцию и восстановление;
ни эта опись, ни проход unit tests не закрывают его.
