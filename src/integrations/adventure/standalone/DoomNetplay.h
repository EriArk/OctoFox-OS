// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "StandaloneAdapter.h"
namespace trainer::doom {
QString bundleRoot();
QJsonObject netplayIdentity(const AdventureRegistration&, const std::atomic_bool&,
                           const std::function<void(const QString&)>& observe = {});
ProcessCommand command(const AdventureRegistration&, const QJsonObject&, QString connection,
                       bool host, const QStringList& inputPrefix = {});
ProcessCommand soloCommand(const AdventureRegistration&, const QStringList& inputPrefix = {});
}
