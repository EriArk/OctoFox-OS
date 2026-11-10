# Возобновлённая проверка портативок — 10 ноября 2026

Владелец возобновил аппаратные проверки и отдельно поручил обновить Armada
на обеих портативках. Доступ использует SSH через сервер владельца. Это
продолжение подготовки Alpha; Bazaar и проверка игрового мультиплеера не входят
в этот проход. Suspend/lid tests не выполняются.

## Armada

Использован штатный `bootc upgrade` с сохранением подписанного
`ghcr.io/armada-os/armada:testing`. Это канал upstream Armada, не дополнительный
канал TrainerOS. Пользовательские разделы не форматировались.

| Устройство | Исходная версия | Подтверждённый результат |
| --- | --- | --- |
| Flip 2 | 20261109.3e75201 | После перезагрузки: 20261110.066ecdc; SSH, Steam и Desktop работают; карта смонтирована; failed system units отсутствуют |
| Odin 2 | 20261106.d5c23cd | После штатной перезагрузки: 20261110.066ecdc; новый boot ID; failed system units отсутствуют; карта смонтирована; профиль и бинарник сохранены |

Образ 20261110.066ecdc имеет digest
`sha256:adbf8f576ac38ba2c834b4a9c73ee5b1d80bfc4e7908dd6375f733850f490f76`.
На Flip сохранён откат на 20261109 и закреплённый Iris. Первый reboot вернулся
на старую версию: upstream EFI helper пытался скопировать ядра всех старых
закреплённых deployments и потребовал 504037376 свободных байт в ESP с 430 MiB.
Удалена только устаревшая vanilla-запись 20261017; её commit удержан отдельным
OSTree ref, конфигурация сохранена. После этого обычный helper синхронизировал
124 файла, и повторная загрузка активировала новую Armada.

На Odin до обновления сохранены профиль, бинарник и boot/session configuration;
SQLite backup прошёл quick_check. Устаревшие vanilla/Fedora boot entries сняты
с сохранением их commit refs и конфигураций; текущая система и Iris оставлены.
При завершении обновления `sync` ожидал крайне медленную запись microSD.
Наблюдалась работа очереди, а не доказанная неисправность карты. TrainerOS
остановлен штатно, громкость установлена в 0. Временное runtime-only увеличение
TimeoutStopSec до 20 минут не отключает sync или проверку boot files.
Позже Odin временно перестал отвечать на ping/SSH. Связь восстановилась;
штатная финализация завершилась успешно, EFI helper синхронизировал 124 файла.
После обычной перезагрузки подтверждена новая версия и новый boot ID. Откат
на 20261106 сохранён. Бинарник не изменился, SQLite quick_check — ok,
542 записи adventures сохранены. Принудительной перезагрузки не было.

Обнаружена гонка автозапуска: новый upstream `armada-fixups.service` удаляет
старый `zz-steamos-autologin.conf` после переноса на `zz-holo-autologin.conf`.
TrainerOS выбирал default параллельно, поэтому его выбор мог быть удалён.
В session drop-in добавлено `After=armada-fixups.service`; прежнее упорядочивание
перед SDDM сохранено. Это сохраняет совместимость со старой Armada и штатными
переключателями Desktop/Steam, не изменяя upstream scripts. На Odin сохранён
исходный drop-in и установлено исправление; проверка reboot продолжается.
Подписанный комплект 21/22 был собран раньше и этого исправления не содержит.

## Новый комплект TrainerOS

Независимая ARM64 Release-сборка на сервере из
`300493967279d0dfe7e738a1162e0f78f0ed2092` включает последние изменения
визарда/QR, Settings, Apps, Browser/Files, Chats, профиля и всплывающих окон.
В окружение сборки добавлен Qt WebEngine ARM64: старый cross-builder находил
его как NOTFOUND. Проверено фактическое `TRAINER_WEBENGINE=1` в новой сборке.

Git source archive сверён с исходниками. 45 исключённых из экспортируемого
архива raw avatar build inputs получены отдельно из точных HEAD blobs и
сверены по SHA-256; они не добавлены обратно в публикуемый source archive.
Проверки approved face, 336 eye poses и pack collection прошли. Подготовленный
пакет содержит 45 проверенных compact avatar resources и частные библиотеки
Files; личные аккаунты, BIOS/ROM и сохранения в пакет не включены.

- ARM64 install ELF: `30e1dd681c915c624dc274510c6af7be13cbb52b4499a3966f9df3cc8696e7fb`.
- Build ELF: `630d89fa05f56a2d7207b42fa4c10a940f5ccfa21fc88e8976dd2e443ebafd6c`.
- Различие ELF при CMake install ограничено padding RUNPATH.
- Full Setup: 1824655360 байт; SHA-256
  `78a1b01fcc7a9531f2e742aedd6c1c60d869ac150cf42b28aebee2da214cc500`.
- Software baseline 21, OTA target 22, runtime 24. Пара Software содержит один
  код и предназначена для проверки механизма обновления, не двух разных функций.
- Через закрытый HTTPS origin проверена подпись feed и доступность 22 при 21.
  Это ещё не аппаратная проверка download/apply/restart.
- Публичный релиз не открыт; `published`, `redistributionReviewed` и
  `cleanDeviceAcceptance` остаются false.

## Проход на Flip

Перед установкой исходная сессия была Armada/Steam, без установленного
TrainerOS launcher. Сохранялись неполные остатки старого beta/preview Setup.
Неактивный root без receipt/journal/owned files отложен отдельно; его trust и
bootstrap не переименованы в Alpha. Все сохранённые личные profile/runtime homes
и последний pre-clean recovery root оставлены.

Очищены только неактивные распакованные runtime generations двух старых
удалённых установок, staging прерванной установки и generated object/resource
каталоги старой сборки. Проверены отсутствие active/previous receipts, pending
journals и live references. Runtime manifests и code recovery blobs сохранены;
игры, BIOS, saves и runtime-home не входят в удаление.

Новый Setup скачан через HTTPS на microSD, размер и SHA-256 проверены, архив
распакован. Обычный `Install TrainerOS.sh` запущен **один раз** из Desktop при
отсутствующих program/profile roots. Через реальные kdialog окна выбран Alpha
и подтверждена установка. [Подтверждение](setup-confirm.png),
[проверка комплекта](setup-progress.png). Ввод передан виртуальной USB-клавиатурой
через uinput; это удалённая проверка UI, не доказательство физических кнопок.

Установка выполняется. Финал Setup, новый wizard, восстановленные аккаунты,
импорт/запуск, Apps/Quick Apps и реальный OTA пока не засчитаны.
