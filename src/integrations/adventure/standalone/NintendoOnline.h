// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "StandaloneAdapter.h"
#include "platform/emulation/GamePreparation.h"

namespace trainer::nintendoOnline {
struct Setup {
    QString platform, service, config, data;
    StandaloneInstallation installation;
    bool prepared = false;
};
QStringList services(const QString& platform);
QString guide(const QString& platform, const QString& service);
bool mode(const QString& id);
Setup setup(const QString& platform, const QString& stateDirectory);
QList<gamePreparation::File> requiredFiles(const Setup&);
QString check(const Setup&, const std::function<void(const QString&)>& observe = {});
QJsonObject identity(const AdventureRegistration&, const Setup&, const std::atomic_bool&,
                     const std::function<void(const QString&)>& observe = {});
ProcessCommand command(const AdventureRegistration&, const Setup&, const QJsonObject& expected);
}
