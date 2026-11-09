#pragma once
#include <QJsonObject>
#include "core/model/Models.h"
#include <QVariantList>
#include <atomic>
#include <functional>

namespace trainer::gamePreparation {
// Local-only requirements. These paths/console identities never enter Lobby or support exports.
struct File {
    QString id, group, title, root, name, md5, detail;
    qint64 size = -1;
    bool optional = false;
    bool directory = false;
};
struct Inventory { QList<File> files; QVariantList notes; };
Inventory inventory(const QHash<QString,QJsonObject>& profiles, const QString& stateDirectory);
QVariantMap readiness(const QHash<QString,QJsonObject>& profiles, const QString& stateDirectory, const AdventureRegistration& record);
QVariantMap inspect(const File&, const std::atomic_bool& cancel);
QString importFile(const File&, const QString& source, const std::atomic_bool& cancel,
                   const std::function<void(qint64,qint64)>& progress = {});
bool safeRelativeName(const QString&);
QString registerDiscFirmware(const QString& stateDirectory, const std::atomic_bool& cancel);
struct PackResult {
    int installed=0,present=0,unmatched=0;
    bool archiveRemoved=false;
    QStringList problems;
    QString summary() const;
};
PackResult importPack(const Inventory&,const QString& source,const std::atomic_bool& cancel,
                      const std::function<void(qint64,qint64)>& progress={},bool removeArchive=false,
                      const std::function<QString()>& finalize={});
}
