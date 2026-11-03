# Минимальная приёмка мультиплеера TrainerOS Alpha

**Создано:** 2026-11-03. Все чекбоксы **OPEN для итогового публичного release commit**, даже если есть старые успешные тесты. Это план проверки, не результат. Решение владельца: неполная совместимость допускается в Alpha, если обещания ограничены.

## 0. Обязательная фиксация окружения

- [ ] Release SHA/commit, channel/build, Setup/runtime receipt versions, Armada version/kernel/Iris, core+BIOS hashes без передачи личных файлов, контроллеры
- [ ] Host/guest устройства, точный game title/region/ROM revision, P1/P2, **тип сети** (`same WiFi`, `separate ISP`, `public relay`, `direct ICE`)
- [ ] Дата/время, логи и снимки **реальных действий**, а не только `Connected`
- [ ] Бэкапы/состояние сохранений до теста и после, корректная очистка процессов/портов

## 1. Минимальный проход для заявленного Online Lobby — высокий приоритет

- [ ] Online → Lobby: вход Fluxer, поиск/фильтр, Create/My Lobbies, доступ private/public/approval
- [ ] Создать комнату, выбрать NES Pong (или другой уже доказанный exact profile), пригласить второго, назначить P1/P2, проверить, что оба видят игру/режим
- [ ] Без ROM у гостя показать конкретный `Import your game` и **не** выполнять скрытый download/подмену чужой ROM
- [ ] У гостя та же игра, но другая конфигурация runtime/BIOS → отказ **runtime mismatch**, а не ложное «отсутствует файл»
- [ ] Prepare и Ready обоих, убедиться, что до нажатия host Start **игра не начинается**
- [ ] Host Start → реально отдельные P1/P2 работают в одной игре, два видимых независимых действия
- [ ] Home → Exit гостя → возврат в **ту же** комнату; проверить сохранение game process хозяина
- [ ] Если профиль поддерживает, явный Rejoin game с прежней игрой/прогрессом хозяина
- [ ] Изменить игру/relay/место → Ready сброшен; stale ticket/старый Ready не запускает
- [ ] Конец игры/комнаты → закрытие только owned game и network helpers; личные сейвы не повреждены

## 2. Safety / recovery — важнее широкой совместимости

- [ ] С работающей **обычной** игрой вход в другую lobby требует сохранить/закрыть; Cancel ничего не убивает
- [ ] Имитация неуспешного save/finalizer — новый game process не запускается
- [ ] Потеря связи в комнате/запоздавший signaling/restart shell не восстанавливает Ready без проверки
- [ ] Отмена подготовки не активирует пришедший поздно результат
- [ ] Player/account/profile сменён — старые invitations/seat/room tickets не допускают game launch
- [ ] Owner Leave → проверить фактическое поведение и согласовать с UI (сегодня код закрывает room, доки обещают handoff)
- [ ] Live directory bot работает с **тем же max16** и не публикует недопустимые объявления
- [ ] Данные двух профилей/сейвы отдельны; временный режим NetPlay не перезаписывает ordinary save
- [ ] Нет лишних runtime/media/virtual controller процессов после выхода

## 3. Один контролируемый тест на каждое **заявляемое** семейство

| Семья | Минимальная игра / сценарий | Не включать в обещание без теста |
| --- | --- | --- |
| RetroArch shared | NES Pong; при возможности SNES Contra III | Все NES/SNES/FBNeo/PS1 автоматически |
| PSP Ad Hoc | Ridge Racer или Virtua Tennis, тот же edition на обоих | Sonic Rivals 2, общий «PSP полностью совместим» |
| Native linked/LAN | По одной реально проверенной игре, выбранной из GameCube/Vita/PS2/GB | 56 PS2 игр, Xbox/System Link/Model3 все titles |
| Local без аккаунта | Два handheld same Ethernet/WiFi, обнаружение, согласие, Start | Не перенести Online-only mode в Local |
| Remote Play **2P**, если включён в Alpha | Host NES Pong, guest без ROM, кадр+звук+реальный ввод P2, guest exit/rejoin; тест на текущем Iris | Не обещать без свежего теста 2P; точно не обещать 3–4 guests |
| Go Live / Watch, если включён в Alpha | Один game-only capture без desktop/private notifications, зритель Watch/Stop, call продолжается | Не приравнивать к Remote Play |
| Group voice, если включён | Установка реального устройства ввода/вывода, mute, звонок во время игры, выход без сброса | Synthetic tone не подтверждает человеческую речь |

Тестировать **два разных ISP** только для тех online-сценариев, которые в публикации обещают интернет-подключение вне домашней сети. При отсутствии испытания честно указать ограниченную проверку и возможные проблемы NAT; это не обязательно блокирует экспериментальную альфу.

## 4. Необязательные последующие проверки (не автоматические блокеры)

- [ ] Сложные NAT, TURN/relay для Remote Play, длительные ISP разрывы/мобильные сети
- [ ] 3/4 **физических** участников в игре, в том числе Remote Play один encoder на P2/P3/P4
- [ ] Full PS2 56-title, Xbox native Link, Model3 Cabinet, Wii U external services
- [ ] Quality/echo/headset, 30–60 минут непрерывной нагрузки и battery impact
- [ ] Повтор Steam Deck/PC cross-architecture после точного комплекта runtime и controller profile
- [ ] 16-member общий Lobby с real bot и зрителями, а не synthetic client only

## 5. Шаблон карточки результата

```md
### GAME / MODE / EDITION — DATE
- Release SHA / runtime / core / ROM identity:
- Host OS / device / network:
- Guest OS / device / network:
- Entry point: Home / Online Lobby / Game Options / Local
- Admission: roles/seats/ready/ticket:
- Observed independent P1/P2 gameplay:
- Return / Rejoin / cancellation:
- Ordinary save integrity and remaining helpers:
- PASS / PARTIAL / FAIL:
- Artifacts (screenshot/log/test):
- Known limitations:
```

Ссылки: [общий аудит](MULTIPLAYER_AUDIT.md), [Lobby](MULTIPLAYER_LOBBY.md), [платформы](MULTIPLAYER_PLATFORMS.md), [игровой журнал](MULTIPLAYER_TESTED_GAMES.md), [риски](MULTIPLAYER_RISKS.md).