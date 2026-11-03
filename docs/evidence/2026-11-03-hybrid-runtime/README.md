# Hybrid runtime и совместимость версий — 3 ноября 2026

## Реальные результаты

- [Полный Setup-кандидат](setup-candidate.json): **3 947 827 200 байт**, SHA-256
  `b8ea4951fafa5066d8d0bef1dc728055bd8f3d81938caa0fd41a21cb31fdce44`.
  Bootstrap из `b4efcb2d`, Software `2a6c9c9b`, runtime sequence 12.
  [Независимая проверка](setup-verification.json) перечитала весь архив: 72 bootstrap
  файла, подписи/архивы Software и runtime, source archive и hybrid README совпали.
  Подпись сделана прежним тестовым ключом на Flip; сервер получил только публичный
  ключ и готовую подпись. Закрытый ключ не переносился. Сборка остаётся частным
  кандидатом без публичного source/license approval.


- [Runtime archive](hybrid-media.json): 3 017 103 360 байт, SHA-256
  `7f4543254d460507c4676af15534e81d41b0c3a41036d9bb771c9b9a1a825f97`.
  Собран в отдельной рабочей папке microSD Flip, все 127 вложений проверены.
- [Сравнение](comparison.json): удалён только DuckStation/component.tar.gz,
  заменён только его component.json. 126 остальных записей сохраняют прежние
  размер и SHA-256. PS1 PCSX-ReARMed и остальные multiplayer bundles не менялись.
- [Настоящая загрузка](official-download.json): официальный GitHub asset 673935636,
  87 900 416 байт. SHA-256 совпал с имеющимся AppImage; скачанный эмулятор не запускался.
  API binary-response проверен, не только metadata JSON.
- [49 Linux-проверок](linux-checks.log) с `umask 077`: прерывание/продолжение,
  несовпавшая версия/хеш, неизвестный source/asset, отсутствие внешнего бинарника
  в media, неприкосновенность прежней установки, ownership/recovery и source material.
  Первая попытка стенда выявила недостающий catalogue import и permissive server
  umask в тестовом fixture; зависимости/окружение стенда исправлены, итоговый прогон
  зелёный. На Windows отдельно прошли 11 новых проверок.
- На реальном старом пакете обнаружен mode 0644 у DuckStation. Чтением установленного
  Flip подтверждены 0644 также у eden/rpcs3; ARMSX2/Azahar/Cemu/melonDS имеют 0755.
  Исправлен сборщик и проекция старых кандидатов: AppImage получает 0755 без изменения
  содержимого. Linux-тест проверяет настоящий chmod/байты и сохранение чужого EmuDeck.

## Реализация

`runtime_upstream.py` получает только проверенный source/числовой asset ID. Descriptor
находится внутри подписанного runtime media. Размер/хеш неизменны; не запрашивается
новейший release и не исполняется чужой installer/script. Старый runtime до завершения
подготовки не меняется; partial download сохраняется для продолжения.

`upstream_media.py` преобразует проверенное автономное media, только если официальный
asset совпадает с выбранной сборкой. Старый оригинал сохраняется. `offline_setup.py`
помечает новый Setup как hybrid и сообщает о нужном интернете; всё остальное
остаётся в существующем install/rollback journal. Конфигурация генерируется нашим
кодом в private runtime-home/частном сеансе, не поставляется как изменённый DuckStation.

```sh
python3 packaging/software/upstream_media.py TrainerOS-Full-CANDIDATE.tar \
  --plan packaging/emulators/upstream-arm64.json --output TrainerOS-Hybrid-Runtimes-CANDIDATE.tar
```

Runtime media передан `offline_setup.py --archive` вместе с `--runtime-manifest`:
предварительно подписанная опись сверяется по sequence, Software source, полному
списку файлов и хешу/размеру архива. Это позволяет собрать большой Setup на сервере,
не переносить закрытый ключ и не занимать ещё 4 ГБ на почти заполненной microSD.
Полный Setup собран и независимо проверен; публичного GitHub release нет.

## Что не проверено и не доставлено

Новый runtime/Setup на Flip не активирован; права установленной тройки пока не
менялись. Odin не использовался. Отдельная сессия/оболочка/игры/сохранения не менялись.
Не проводились новый игровой матч, разные сети или физические проверки. Эти
результаты не означают рабочий multiplayer всех solo-платформ.

[Матрица версий, выбор runtime и конкретная очередь](../../MULTIPLAYER_RELEASE_MATRIX_RU.md).
