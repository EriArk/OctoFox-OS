// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "integrations/adventure/retroarch/RetroArchNetplay.h"
namespace trainer::ngpc {
QString bundleRoot();
QJsonObject netplayIdentity(const AdventureRegistration&,const std::atomic_bool&,const std::function<void(const QString&)>& observe={});
ProcessCommand command(const AdventureRegistration&,const QJsonObject&,QString connection,bool host,QString owner,const QStringList& inputPrefix);
}
