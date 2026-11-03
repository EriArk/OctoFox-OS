# Мультиплеер: транспорт, Remote Play, стримы, звонки, Nearby

**Срез:** `e4e16a713e3496042d4284f3f8ec7b337f98fc80`, 2026-11-03, анализ исходников и исторических отчётов. Не выполнялись новые реальные сетевые/аудиотесты.

## Сетевая схема по слоям

```text
Fluxer account / Social / room        ← кто вправе играть, приглашения, чат
           │
      Lobby coordinator                ← members, seats, game/mode, Ready, Start
           │
      Runtime preparation              ← local content, core, BIOS, own saves, ticket
           │
       ┌───┼───────────────────────┐
       │   │                       │
  RetroArch/PPSSPP relay         ICE/DTLS Native LAN
  input/state / Ad Hoc           own-console packets
       │                               │
    emulator game                 emulator game
       
Remote Play: one HOST game → H.264/Opus → ICE → guest video
                                        ← remote controller input (P2/P3/P4)

Watch: HOST game → game-specific PipeWire capture → Fluxer LiveKit → viewers
Voice: common Fluxer group call (independent of game party)
Local Lobby: same-LAN UDP discovery + TLS (instead of Fluxer control)
Nearby Link: Bluetooth RFCOMM / local link, own-save transactions
```

## 1. Game NetPlay, direct, relay

`RetroArchNetplay`: официальный NetPlay для deterministic shared-console; выбраны одинаковые game/core/profile settings. Для онлайн используется региональный **публичный relay**, выбор Auto учитывает TCP-замеры участников, manual задаёт точный регион без скрытого fallback. Регионы Madrid/New York/São Paulo/Singapore. Это выбор маршрута, а не гарантия низкого RTT, jitter или working core.

`PPSSPP`: native Ad Hoc/relay; отдельное меню выбора Standard internet relay или **relay on host handheld**, последний организует временный aemu-сервер на host, с ICE/DTLS и локальными портами. Текущий вариант host-relay — **2 игрока**, специфическая игра по-прежнему способна отказать при переходе в матч (Sonic Rivals 2).

`Native LAN`: PS2 ARMSX2 DEV9, xemu System Link, Dolphin BBA, NGPC, Flycast cabinets, Model3, Doom используют независимые протоколы и собственные экраны/данные. `LobbyConnection`/ICE служит аутентифицированным транспортом/запуском; **игра сама должна поддерживать нужный сетевой режим**. Host-transport не является произвольной L2/VPN сетью игрока. Ключи и соединение ограничены актуальным членством/ticket/generation.

[relay selection](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/NETPLAY_RELAY_SELECTION.md), [native carrier per guest](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/adventure/RuntimeLobby.cpp), [version fidelity](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_RELEASE_MATRIX_RU.md).

## 2. Remote Play — гость без ROM

Одна работающая игра на хозяине; отдельный минимальный игровой клиент гостя получает видео H.264 и Opus audio, а свои кнопки отправляет как разрешённый remote pad. Сообщения приглашения и ICE-кандидаты передаются **через Fluxer**, но **не** игровые видео/аудиоданные; используется прямой ICE путь и публичный `stun:stun.l.google.com:19302`. TURN/постоянный relay владельца для плохого NAT **не развёрнут**. Ввод гостя привязан к ticket, account/seat и текущей игре хозяина; stale/grant revocation сбрасывает ввод. Без ROM/BIOS у гостя не создаётся чужой ROM save или RA achievement.

**Факты:** 14.10 реальная Flip(хост NES Pong)→Odin(гость) через живой Fluxer с первым кадром, выходом/повторным P2 и сохранённым host PID/room. **Оба были за одним роутером**. Код `RemotePlayRuntime` сейчас допускает до **трёх гостей**, capacity 2–4, но **не принят** трёх/четырёхпользовательский media session: многогостевой клиент получал audio и **0 decoded frames**, поздний Fluxer-тест чернел/прерывался. `REMOTE_PLAY_GROUPS.md` — кандидат, а не автоматический production pass. [текущий multi-peer source](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/adventure/RemotePlayRuntime.cpp), [прошедший 2P](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/REMOTE_PLAY_LOBBY.md), [непрошедший multi](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/REMOTE_PLAY_GROUPS.md).

**Iris:** на ядре `7.2.6-traineros-iris1` 23.10 успешно проверен IDR/SPS после запроса, но 25.10 официальный Armada OS обновил kernel/Iris, и прежний test больше не доказывает наличие патча; Remote Play на новом baseline заново не проверялся. [kernel and encoder evidence](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/ARMADA_IRIS_ENCODER.md).

## 3. Go Live / Watch — не Remote Play

Через существующий разговор Fluxer/LiveKit хозяин явно выбирает **Share game with this call**, зритель — **Watch** у конкретного участника. Запрос на просмотр/выход не забирает контроллер и не требует ROM/Ready. Захват выбирает **процесс/окно своей игры** (XRes PID, Gamescope PipeWire), не полный рабочий стол; неизвестный владелец окна/Flatpak instance fail closed. Аудио берётся из собственной game sink stream, не из всех звуков ОС, микрофон не включается автоматически. В существующем описании ограничено **до 1280×720 / 30 fps**, но это профиль stream capture, не measured gameplay latency.

**Проверено 13.10:** живой Fluxer Flip→Odin, синтетический контент/440Hz и отдельный микрофон 880Hz, >120 кадров, затем реальный экран NES Pong >80 кадров и остановка без окончания звонка. **Не проверено:** качество тяжёлых сцен, длительный сеанс, разные интернет-сети, несколько одновременно транслирующих, человеческая речь. [зрители и capture](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY_MEDIA.md).

## 4. Один общий голосовой звонок

Голос принадлежит **Fluxer группе/сообществу**, не отдельной game party; он может продолжаться при смене игры, выходе гостя и создании другой партии. Два реальных устройства через общий звонок во время NES Pong netplay пережили 12-секундное прерывание только игровой связи — тон продолжился, voice worker PID не менялся. **Это синтетическое измерение**, без слышимого голоса, echo, настоящего микрофона, гарнитуры и реального WAN. Не обещать voice quality. [shared group call](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/GAME_PARTIES.md), [human-audio gates](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/SOCIAL_MEDIA_VOICE.md).

## 5. Nearby Link и Offline Lobby

- **Nearby Link**: обнаружение через Bluetooth RFCOMM по умолчанию, независимый same-LAN fallback; Wi-Fi Direct — только явный экспериментальный путь (старый Odin freeze). Для поддерживаемых game-save адаптеров: отдельные предложения Trade / Give / Sell / Battle, защищённый commit/rollback и согласие обеих сторон. Это **не** NetPlay любого картриджа.
- **Local Lobby**: тот же room model, но discovery UDP+TLS на одном Wi-Fi/Ethernet, без Fluxer и without provider call. Локальные игры допускаются только при поддержанном профиле, online-only/Remote Play не становятся Local автоматически. Есть тесты socket/identity/child process в loopback, реальной 2-device Local acceptance этой версии не доказано.

[Nearby](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/NEARBY_PLAY.md), [Offline Lobby](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/OFFLINE_LOBBY.md), [Local TLS](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/platform/network/LocalLobbyTransport.cpp).

## 6. Словарь доказательств для сети

| Наблюдение | Доказано | **Не** доказано |
| --- | --- | --- |
| Получен ICE/DTLS connection | Есть канал между конкретными процессами | Геймплей, правильная игра, NAT-тяжёлые сети |
| Public relay с двумя устройствами за одним роутером | Реально использовался внешний сервер для игры | Связь через **два разных ISP/NAT** |
| Packet fixture между 4 native endpoints | Bridge выдержал 4 input/session | 4 человека со своими портативками в полной игре |
| Relay ping 150 ms | Публичный endpoint был доступен при пробе | Стабильность/задержка игры |
| Видео >80 декодированных кадров | Зрительский/guest stream работал в том тесте | Устойчивость часов, физический input, низкая latency |
| Synthetic 440Hz tone | Sound data доставились без gap в измеренном интервале | Человеческая речь, echo, bluetooth headset |
| Успешный возврат одного P2 | Поддержанный explicit rejoin существует | Универсальный автоматический late join всех эмуляторов |

Результат приёмки записывать по точной архитектуре, версии, записи и сети; см. [MULTIPLAYER_ACCEPTANCE.md](MULTIPLAYER_ACCEPTANCE.md).