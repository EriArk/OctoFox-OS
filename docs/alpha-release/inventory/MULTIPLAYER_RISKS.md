# Риски и несоответствия мультиплеера перед TrainerOS Alpha

**Срез:** исходники `e4e16a713e3496042d4284f3f8ec7b337f98fc80`, 2026-11-03 и датированная история. **Не создавались новые баги и не изменялся исполняемый код.** Ниже риск/недостающая приёмка не обязательно означает блокер выпуска: владелец разрешил ограниченную альфу.

## A. Случаи, которые нужно разрешить до соответствующего публичного обещания

| Приоритет | Обнаружение | Источник | Решение |
| --- | --- | --- | --- |
| **P1 / честность UI** | [LOBBY.md](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY.md) обещает передачу комнаты при `Leave` хозяина, но `LobbyRoomCoordinator::leave()` и `LobbySession::leave(owner)` **закрывают комнату** и шлют `closed` | [Coordinator](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/LobbyRoomCoordinator.cpp), [Session](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/features/social/LobbySession.cpp) | Уточнить ожидаемое поведение: реализовать безопасный handoff или убрать неверное обещание и проверить UX |
| **P1 / server version** | Изменение на **16 участников** есть в source, но [документ бота](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/services/lobby-directory/README.md) прямо сообщает: 25.10 новая версия бота **не развернута** | Сервисный журнал | Проверить фактический бот, max member policy и fallback в live каталоге |
| **P1 / UI** | Старый путь `GameHub → Lobby` в активных документах противоречит текущему `Online → Lobby` | [Shell](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/src/core/navigation/ShellController.cpp) | Описывать актуальную вкладку; старые инструкции отметить историческими |
| **P1 / Remote Play** | Код multi-peer до 3 гостей есть, но 14.10 многогостевая видео-проверка **не прошла** | [multi-guest](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/REMOTE_PLAY_GROUPS.md) | Не писать 3–4-guest playback until 2 clients simultaneously decode/respond and host PID retained |
| **P1 / encoder baseline** | Patched Iris прошёл IDR тест 23.10, но 25.10 обновление официальной Armada сменило модуль и старое доказательство устарело | [Iris](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/ARMADA_IRIS_ENCODER.md) | Проверить IDR/SPS, реальный кадр/синхронизацию после текущего Setup |
| **P2 / offline** | Local Lobby есть в коде и TLS loopback tests, но документ не подтверждает реальную пару Flip/Odin без Fluxer | [Local Lobby](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/OFFLINE_LOBBY.md) | Физический same-network pairing на конкретной alpha сборке |
| **P2 / WAN** | Все известные external-relay парные игры были через **один домашний роутер** | [парные примеры](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/EMULATOR_MULTIPLAYER.md), [NES relay](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/GAME_PARTIES.md) | Не обещать universal internet/NAT; протестировать конкретные пары с двумя разными ISP |
| **P2 / voice** | Синтетические тоны проходят, не проведены реальные голос/гарнитура/echo | [голосовые требования](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/SOCIAL_MEDIA_VOICE.md) | Пометка экспериментальности, ручная проверка владельцем если решит |
| **P2 / game-specific** | PSP Sonic Rivals 2 неустойчив на старте гонки; Tekken нестабилен; PS2 config input/graphics issues | [точный журнал](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_TESTED_GAMES.md) | Указать баги; Sonic/PS2 пользователь отложил, не возвращать их в релизный блокер без решения |
| **P2 / catalog** | PS2 56 LAN titles/164 serial и исходная подборка 321 игр могут выглядеть как 321 проверенная игра | [PS2](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/PS2_NATIVE_MULTIPLAYER.md), [подборка](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/MULTIPLAYER_SELECTION_DELIVERY.md) | Не смешивать detectability, file copied, runtime candidate и actual pair pass |
| **P2 / SDK PC** | PC Games/import и платформа поддерживают не любой native PC LAN; #251 отдельно не готово | [PC LAN remains separate](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/OFFLINE_LOBBY.md) | Не включать PC LAN как реализованный режим Alpha |
| **P2 / stream** | Watch и Remote Play используют разные видео/права/задержку, а тяжелая сцена и multi publisher не проверены | [stream boundary](https://github.com/EriArk/TrainerOS/blob/e4e16a713e3496042d4284f3f8ec7b337f98fc80/docs/LOBBY_MEDIA.md) | Описывать зрителей как view-only, различать с Remote Play |

## B. Известные границы, допустимые для ограниченной альфы

- Не все эмуляторы/игры/форматы ROM, BIOS, online services работают; **solo не означает multiplayer**.
- Не гарантируется работа прямого ICE за строгим NAT, owner TURN/relay для Remote Play **не развёрнут**.
- Четыре **логических** native linked процесса не равны четырём физическим игрокам; 16 членов room не равны 16 pads.
- Native Online Wii/3DS/DS WFC/Wii U зависит от индивидуальных сервисов/учёток и не доказывает возможность пройти матч.
- **Нет принятой поддержки** для PS3, Xbox360, Switch multiplayer и generic PC LAN.
- **Manual Rejoin** поддержан лишь у точных профилей с сохранением P2, другие mid-game connections не обещать.
- Физическое качество звука/гарнитур, длительная нагрузка, battery/GPU и полный Iris verification после последней смены ОС открыты.

## C. Что является реальной угрозой пользователю, а не просто незавершённой фичей

Потеря сейвов, перепутанный чужой profile/account, запуск под старым invitation/ticket, подмена firmware/content, созданные без согласия дополнительные процессы, неосвобождённые input leases или игнорирование отмены — **принципиально важнее** количества поддерживаемых игр. Код уже содержит guard/finalizer/recovery; перед выпуском нужно пройти *минимальный* end-to-end сценарий на **конкретном** alpha candidate. См. [MULTIPLAYER_ACCEPTANCE.md](MULTIPLAYER_ACCEPTANCE.md). В отличие от неполного игрового списка, опасный сбой сохранности нельзя объявить «всего лишь альфа».

**Вердикт аудита:** мультиплеер не «макет», а несколько реально проверенных путей; однако формулировка «любая ретроигра с друзьями из любых сетей» **не подтверждается**. Для alpha допустима ограниченная витрина проверенных сценариев и честных проблем. 
