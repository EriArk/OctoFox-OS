# Crates — каталог игр, программ и дополнений TrainerOS

> **Аудит:** 2026-11-03, **CODE** + предшествующие датированные device/test evidence.  
> TrainerOS source: `6d394850d23c46fe610446f0d202315db25295a5`; Crates source: `fea662d59d30026ebb72546dad9a20631cc7ff0f`.  
> Новый физический тест этим документом **не проводился**.

## Что это и зачем

**Crates — встроенная витрина программ и небольших игр, которые можно установить и обновлять прямо из TrainerOS.** Её смысл в том, чтобы пользователь выбирал проект по описанию и картинкам, а не вручную подбирал архивы, команды запуска и место установки. Сама игра затем появляется в **Games**, приложение — в **Apps**, а совместимые виджеты становятся доступны через **Start** или **Home**.

Crates расположен в **Online → Crates**. Не является игровым лобби, социальным сервером или готовым Bazaar.

## Как выглядит

Сначала шесть визуальных «ящиков»: What's New, Workshop, Adventure, Arcade, Strategy, Tools & Modules. Внутри — сетка по шесть проектов на страницу. Карточка раскрывает иллюстрации/скриншоты, название, автора, короткое описание, лицензию, версию, размер, архитектуру и статус совместимости. За открытым описанием **ничего автоматически не скачивается**.

Подробнее: [полное дерево и UX](../inventory/CRATES_AUDIT.md).

## Что уже реализовано

| Действие игрока | Результат / поведение | Текущий статус |
| --- | --- | --- |
| Выбрать ящик/проект | Открыть сетку/карточку, просмотреть описание/изображения | CODE; есть UI smoke |
| Download | Добавить установку подходящего пакета в общий Downloads | CODE; исторические physical tests Odin/Flip |
| Install anyway | Явно согласиться на экспериментальную сборку | CODE; статус `incompatible` требует отдельного исправления текста/политики |
| Play / Open | Игра в Games, приложение в Apps либо выбранный Home-widget | CODE; подтверждены отдельные реальные пакеты |
| Update / Update all | Скачать опубликованное обновление, сохранить прежние данные и previous object | CODE; исторические 4 реальные обновления 22.10 |
| Automatic Crates updates | По желанию игрока следить за установленными `supported` пакетами | CODE; настройка в Settings; тесты и device UI 26.10 |
| View progress | Открыть очередь Downloads, где доступны пауза, retry, отмена | CODE, тестовые recovery-циклы |
| Remove | Через отдельную корзину и подтверждение удалить код, **сохранив пользовательские данные** | CODE + тесты |
| Reinstall | Повторная установка с возвращением прежней регистрации игры и данных | CODE + тесты |
| Offline | Оставить ранее проверенную витрину и установленные пакеты, не принимать недостоверный каталог | CODE + тесты |
| Встроить виджет | Session Timer — в Start, Companion — в Home, оба через разные механизмы SDK | CODE; имеются датированные устройства/стенды |

## Содержимое на 3 ноября 2026

Серверный подписанный каталог **ревизии 43** описывает **18 проектов, 81 release record** (версии и архитектуры включительно). Все проекты обозначены **Alpha Preview**, но значительная часть релизов всё ещё Experimental/untested. Это отдельная метка презентации, а не доказательство завершения разработки.

В каталоге есть небольшие сторонние игры (2048/Hextris/Breakout), приложения (FeatherPad/Qalculate!), девять авторских аркад, Pocket Golf, Micro Rally, Session Timer и Companion. У разных проектов разные границы готовности; [подробная таблица 18 проектов](../inventory/CRATES_PROJECTS.md).

**Большая коллекция идей `EriArk/crates` не равняется большой коллекции готовых установок.** Всего в ней 24 концепции соревновательных мини-игр, 9 из которых имеют реализацию в main; большинство собственных Apps, Widgets и Extensions пока только в документах. [Реестр концептов](../inventory/CRATES_CONCEPTS.md).

## Важные границы

- Пакеты скачиваются только из разрешённых подписанным каталогом GitHub Release assets, с проверкой хеша и размера. Это не открытый магазин произвольных исполняемых файлов.
- Crates не подменяет ROM/BIOS и не превращает игры в универсально совместимые с железом.
- Автоматические обновления выключены по умолчанию и не устанавливают `untested` релизы самовольно.
- Установки и удаления используют собственные данные/receipt и не удаляют игровую историю; при crash во время операции есть сценарий восстановления, но это **не** гарантия полного hardware power-loss recovery.
- **Session Timer** сейчас зависит от запущенного приложения; **Companion** — от версии оболочки и доверенного рендера. Пакеты отличаются от обычных desktop-программ.
- Отдельного работающего каталога нативных плагинов/системных расширений, магазинов Sparks/покупок и Bazaar из этого аудита **не следует**.

## Где лежит код и какие проверки проведены

- QML: [CratesPage](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesPage.qml), [Catalogue](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesCataloguePage.qml), [Project popup](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/qml/CratesProjectPopup.qml).
- Controllers: [CratesController](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesController.cpp), [CratesInstaller](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesInstaller.cpp), [CratesLibrary](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/src/features/crates/CratesLibrary.h).
- Trust/installer: [packaging/crates](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/packaging/crates/README.md), [Home contribution](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/sdk/HOME_WIDGETS.md).
- Проверки: [датированный catalog/device log](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/CRATES77_CATALOGUE.md), [update tests](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/crates-updates-20261026/README.md), [recovery tests](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/evidence/crates-recovery-20261026/README.md), [Companion 02.11](https://github.com/EriArk/TrainerOS/blob/6d394850d23c46fe610446f0d202315db25295a5/docs/FEATURE_READINESS.md).
- Обязательная следующая проверка: [Crates acceptance](../inventory/CRATES_ACCEPTANCE.md) на итоговом release commit.

## Короткое описание для будущего поста — ещё не финальный текст

Crates позволяет находить и устанавливать игры, приложения и совместимые дополнения прямо в TrainerOS. Выбираете проект, смотрите описание, скачиваете проверенный пакет — и запускаете его из обычной библиотеки Games или Apps. Обновления и удаление используют общую очередь, а пользовательские данные сохраняются отдельно от исполняемых файлов. Каталог альфы уже содержит экспериментальные авторские мини-игры и отдельные приложения, но совместимость и готовность зависят от конкретного проекта и устройства.
