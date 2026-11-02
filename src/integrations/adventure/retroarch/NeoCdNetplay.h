#pragma once
#include "RetroArchNetplay.h"
namespace trainer::retroarch {
QJsonObject neoCdIdentity(const AdventureRegistration&, const RetroArchInstallation&,
                         const std::atomic_bool&, NetplayDigestCache*);
QString prepareNeoCd(ProcessCommand&, const RetroArchInstallation&, const QJsonObject&,
                     const QString& directory, const std::atomic_bool&);
}
