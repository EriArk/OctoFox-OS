# Nintendo Online services — подготовка 2 ноября 2026

Источник реализации: `NintendoOnline.{h,cpp}`, обычные `SettingsController`,
`RuntimeMultiplayer` и существующий владелец дочернего процесса. Это native
Online через сервер игры, отдельно от Dolphin NetPlay/BBA, Azahar Wireless
и DS WFC. На портативки этот прирост не устанавливался.

## Вход и возврат

Settings → Games & library → Online services: выбрать Wii / Nintendo 3DS /
Wii U, затем сервис, открыть инструкцию, выполнить её в штатном эмуляторе,
подтвердить подготовку и проверить локальные предпосылки. Выключение сервиса
убирает только его дополнительный режим. Прежние NetPlay/Wireless/LAN остаются.

Online → обычное Lobby → отдельный режим сервиса → Ready → явный Start хоста.
Каждый запускает собственную игру; комнату, friend code или соперника выбирают
внутри игры. TrainerOS не выдаёт запуск процесса за вход в сервер или матч.
Home/minimize/exit принадлежат прежнему lifecycle; потеря Lobby не закрывает
уже запущенный native Online. Автозапуска по присутствию и автоматического
возвращения в матч нет. После закрытия сохраняется обычный возврат в оболочку.

## Подготовка сервисов

| Платформа | Сервис | Реальный механизм и локальная проверка |
| --- | --- | --- |
| Wii / Dolphin | Wiimmfi | Пользователь готовит свою NAND и соответствующий патч по [инструкции провайдера](https://wiimmfi.de/patcher/). Проверяются Dolphin и наличие SYSCONF в выбранной NAND. |
| Wii / Dolphin | WiiLink WFC | [Официальный путь Dolphin](https://wfc.wiilink.ca/dolphin): Gecko-патч для региона/ревизии игры, собственная NAND, когда она требуется сервером. Проверка локальной NAND такая же; выбранный сервис имеет отдельную идентичность Lobby. |
| 3DS / Azahar | Pretendo | [Artic Setup для Old и New 3DS, LLE и Nimbus](https://pretendo.network/docs/install/azahar). Проверяются размеры OTP/SecureInfo/LocalFriendCodeSeed, включённый LLE и три Nimbus HTTP replacement rules. |
| Wii U / Cemu | Pretendo | [Собственный PNID/console dump](https://pretendo.network/docs/install/cemu), активный аккаунт с `AccountService/SelectedService Service=2`; размеры OTP/SEEPROM, файл выбранного аккаунта и основные account/common certificates. Полный набор и пригодность аккаунта проверяет Cemu при подключении. |

Подтверждение подготовки — заявление пользователя, не доказательство валидности
сертификатов, NAND, PNID или патча игры. Наличие файлов не проверяет подписи,
доступность сервера или выполнение всех этапов Artic Setup. TrainerOS не
устанавливает Nimbus, не генерирует консольные данные и не патчит ROM автоматически.
Это существующие процедуры эмуляторов/провайдеров, с прямой ссылкой из Settings.
Смена сервиса в TrainerOS выбирает режим Lobby, а не переписывает настройки
аккаунта или патчи в эмуляторе. Несовпадение Cemu/Nimbus блокирует допуск с
понятной причиной.

Нет allowlist из проверенных игр: включённый, подготовленный runtime предлагает
игры подходящего формата. Каталожное «1 local player» не скрывает independent
Online. Наличие карточки означает возможность запуска этого режима, не наличие
сервера для любой игры. Реальная поддержка зависит от сервиса, игры, региона,
обновления и патча. Группа TrainerOS сейчас 2–4; это не предел сервера игры.

Форматы: Dolphin ISO/GCM/RVZ/WIA/WBFS/CISO/GCZ/NFS (включая прежний digest частей),
Azahar CCI/3DS/CXI/APP/3DSX/ZCCI/ZCXI/Z3DSX/CIA/ZCIA, Cemu WUD/WUX/WUA/RPX.
CIA/ZCIA использует существующий проверяемый content helper и получает именно
NAND/SDMC выбранной конфигурации, включая portable/Flatpak. Обновления/DLC не
становятся самостоятельными запускаемыми играми; helper сохраняет прежний отказ.
Хеш RPX сам по себе не удостоверяет весь extracted content/update tree; совместимость
версий native игры остаётся у провайдера. Не заявляется межформатная эквивалентность
по одному названию игры.

## Границы и сохранность

S15 выбирает сервис; S03 проверяет локальную установку и строит команду;
S06/S07 передают только общий descriptor/готовность и назначенное место. В сети
нет путей, OTP, SEEPROM, NAND, friend seed, номера native аккаунта или токенов.
В descriptor остаются режим/сервис, content digest, протокол и вместимость.
Native Online не требует одинаковых бинарников ARM/x86: это не lockstep NetPlay.

Используются существующие installation profiles и их input wrapper. На Linux
учтены стандартные XDG, Flatpak, upstream portable directories и Dolphin `--user`.
Перед запуском повторяются локальные проверки и сравнение descriptor. Lock
исключает второй TrainerOS native Online launch с той же конфигурацией; он не
заменяет собственные ограничения эмулятора/сервера на параллельный запуск.

Сохранения/аккаунты остаются в выбранном native хранилище и пишутся самим
эмулятором как при обычном запуске. Нет seeding чужим save, временной подмены NAND,
автоматического восстановления поверх новых данных, возврата после crash или
savestate. Это не новый атомарный snapshot всего NAND/MLC. При сбое сохраняются
данные, оставленные native runtime; восстановление — его штатными средствами и
собственными резервными копиями пользователя. Передаём закрытие прежнему
владельцу процесса, не добавляем detached emulator или второй сетевой туннель.

## Upstream и сопровождение

Проверены первичные исходники (локальные research checkout в ignored `build/`):

- [Azahar e3c916e4](https://github.com/azahar-emu/azahar/tree/e3c916e41a36ae19f7daa8a98e05492873944071): `src/citra_qt/configuration/config.cpp`, `src/core/hw/unique_data.*`, `src/core/hle/service/http/http_c.cpp`.
- [Nimbus 6876a1f8](https://github.com/PretendoNetwork/nimbus/tree/6876a1f81a14083adaa0f444c46db041fac3d017): `app/source/states/MainUI.cpp`, `handleAzahar`.
- [Cemu 3f8dd913](https://github.com/cemu-project/Cemu/tree/3f8dd913cfd4c8247ad65ab41ba6ef0a55926769): `LaunchSettings.cpp`, `CemuConfig.cpp`, `NetworkSettings.h`, `Account.cpp`, `iosu_crypto.cpp`, `CemuApp.cpp`.

Эти ревизии — контракт аудита, не заявление об установленной версии. Новых
эмуляторных patches в этом приросте нет. Официальная поддержка Pretendo/Azahar
относится к официальным сборкам; сторонний TrainerOS runtime не становится
сертифицированным провайдером. Старая Cemu-инструкция содержит историческое
ограничение 2.0 experimental; действующий контракт сверялся с исходниками,
а не переносился как современное ограничение версии.

При обновлении сверить CLI, portable/XDG layout, LLE/rules и Cemu account/service
XML; запустить целевые native Online и runtime lifecycle tests. Для отката
выключить сервис в Settings или вернуть код прироста; native данные не удалять.

Проверки и точные ограничения сборки записываются в
[evidence](../evidence/nintendo-online-preparation-20261102/README.md).
Консольные данные, live вход и матч предоставят владельцы соответствующих консолей;
это не блокирует исходники и не считается уже пройденной приёмкой.
