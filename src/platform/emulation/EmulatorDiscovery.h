#pragma once
#include <QHash>
#include <QJsonObject>
#include <QStringList>

namespace trainer {
// Installation-time/startup snapshot. Never run discovery from a capability
// getter or while drawing a page. Inventory is injectable for content-free tests.
struct EmulatorEnvironment {
    QString home, configHome, stateDirectory, libraryRoot;
    QHash<QString, QString> executables, flatpaks;
    QStringList nativeCoreDirectories;
    QString controllerName;
    int controllerIndex = 0, playerIndex = 0;
    QString kernelPadName, cemuControllerUuid;
    bool switchPro = false;
    int padVendor = 0, padProduct = 0;
    QHash<QString, int> controllerButtons; // melonDS raw SDL button/hat encoding
    QHash<QString, QString> switchBindings; // Eden native SDL parameter packages
    bool managed = false;
};
struct EmulatorDiscovery {
    QHash<QString, QJsonObject> profiles;
    QStringList notices;
};
EmulatorEnvironment installedEmulators(const QString& stateDirectory, const QString& libraryRoot, bool readController = true);
// SDL device reads must run on the input thread.
void readEmulatorController(EmulatorEnvironment&, int preferredInstance = -1);
EmulatorDiscovery prepareEmulators(const EmulatorEnvironment&);
// Resolve Flatpak's selected branch when `info APP` is ambiguous.
QString currentFlatpakDeployment(const QString& app, const QStringList& installations);
}
