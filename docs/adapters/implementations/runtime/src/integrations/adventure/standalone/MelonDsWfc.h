// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "integrations/adventure/retroarch/RetroArchAdapter.h"
#include <atomic>
namespace trainer::dswfc {
inline constexpr auto Source="f394adbacb5722ee97c1b37c8064da9a25818310";
inline constexpr auto CoreSource="16f127dbb587a73371827ce79689c5d237c4b59b";
inline constexpr auto Settings="ds-wfc-kaeru-owned-v1";
QString bundleRoot();
QJsonObject identity(const AdventureRegistration&,const RetroArchInstallation&,const std::atomic_bool&,
                     const std::function<void(const QString&)>& observe={});
ProcessCommand command(const AdventureRegistration&,const RetroArchInstallation&,const QJsonObject& expected,
                       QString owner,QString backupRoot);
}
