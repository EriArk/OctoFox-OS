#pragma once
#include <QDir>
#include <QProcessEnvironment>
#include <QStandardPaths>

namespace trainer::runtimepaths {
// The shell retains the real desktop HOME. Only emulator children use this home.
inline QString home() {
    const auto value = qEnvironmentVariable("TRAINEROS_RUNTIME_HOME");
    return QDir::isAbsolutePath(value) ? QDir::cleanPath(value) : QString();
}
inline QString data() {
    const auto root = home();
    return root.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                          : root + "/.local/share";
}
inline QString userHome() { return home().isEmpty() ? QDir::homePath() : home(); }
inline QString config() {
    return home().isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                            : home() + "/.config";
}
inline QString profileDirectory(const QString& state) {
    return state + (home().isEmpty() ? "/integrations" : "/integrations/managed");
}
inline QProcessEnvironment environment() {
    auto env = QProcessEnvironment::systemEnvironment();
    const auto root = home();
    if (!root.isEmpty()) {
        env.insert("HOME", root);
        env.insert("XDG_DATA_HOME", root + "/.local/share");
        env.insert("XDG_CONFIG_HOME", root + "/.config");
        env.insert("XDG_CACHE_HOME", root + "/.cache");
        env.insert("XDG_STATE_HOME", root + "/.local/state");
        env.insert("FLATPAK_USER_DIR", root + "/.local/share/flatpak");
    }
    return env;
}
}
