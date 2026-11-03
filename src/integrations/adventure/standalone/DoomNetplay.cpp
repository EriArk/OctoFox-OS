#include "platform/emulation/RuntimePaths.h"
// SPDX-License-Identifier: GPL-3.0-or-later
#include "DoomNetplay.h"
#include "CabinetConnection.h"
#include "core/model/GamePlayers.h"
#include "integrations/adventure/retroarch/RetroArchConfiguration.h"
#include <QCryptographicHash>
#include <QDir>
#include <QElapsedTimer>
#include <QLockFile>
#include <QJsonArray>
#include <QProcess>
#include <QStandardPaths>

namespace trainer::doom {
namespace {
constexpr auto Source = "3a763534ac609aee8d22351baa3155809c4ea355";
constexpr auto Settings = "odamex-owned-native-v1";
bool hex(const QString& s) { return QRegularExpression("^[a-f0-9]{64}$").match(s).hasMatch(); }
bool bundle(const std::atomic_bool& cancel) {
    const auto root = bundleRoot(), canonical = QFileInfo(root).canonicalFilePath();
    QFile f(root + "/manifest.json");
    if (canonical.isEmpty() || !f.open(QIODevice::ReadOnly) || f.size() > 32768) return false;
    const auto m = QJsonDocument::fromJson(f.readAll()).object();
    if (m["protocol"] != 1 || m["source"] != Source || m["settings"] != Settings) return false;
    const auto files = m["files"].toObject();
    const QStringList required{"bin/odamex", "bin/odasrv", "bin/odamex.wad", "content.py", "launch.py", "endpoint.py", "stream_transport"};
    if (files.size() < required.size() || files.size() > 64) return false;
    for (const auto& n : required) if (!files.contains(n)) return false;
    for (auto it = files.begin(); it != files.end(); ++it) {
        const auto n = it.key();
        if ((!required.contains(n) && !QRegularExpression("^lib/[A-Za-z0-9_.+-]+$").match(n).hasMatch())
            || !QFileInfo(root + '/' + n).canonicalFilePath().startsWith(canonical + '/') || !hex(it.value().toString())
            || retroarch::fileDigest(root + '/' + n, 256LL * 1024 * 1024, cancel) != it.value().toString()) return false;
    }
    for (const auto& n : {"bin/odamex", "bin/odasrv", "stream_transport"})
        if (!QFileInfo(root + '/' + n).isExecutable()) return false;
    return QFileInfo("/usr/bin/python3").isExecutable() && QFileInfo("/usr/bin/bwrap").isExecutable();
}
QJsonObject content(const QString& path, const std::atomic_bool& cancel) {
    QProcess p;p.setProcessEnvironment(runtimepaths::environment()); p.setStandardErrorFile(QProcess::nullDevice());
    p.start("/usr/bin/python3", {"-I", bundleRoot() + "/content.py", path});
    if (!p.waitForStarted(3000)) return {};
    QByteArray bytes; QElapsedTimer timer; timer.start();
    while (p.state() != QProcess::NotRunning) {
        p.waitForFinished(50); bytes += p.readAllStandardOutput();
        if (cancel || timer.elapsed() > 180000 || bytes.size() > 262144) { p.kill(); p.waitForFinished(2000); return {}; }
    }
    bytes += p.readAllStandardOutput();
    if (p.exitStatus() != QProcess::NormalExit || p.exitCode() != 0 || bytes.size() > 262144) return {};
    return QJsonDocument::fromJson(bytes).object();
}
ProcessCommand launch(const AdventureRegistration& r, const QJsonObject& expected, const QString& connection,
                      bool host, const QStringList& inputPrefix, bool network) {
    ProcessCommand cmd;cmd.emulatorRuntime=true;
    cmd.runtimeControls = {{"kind", "odamex"}, {"game", r.adventure.id}};
    if (network) { cmd.runtimeControls["netplay"] = expected.toVariantMap(); cmd.runtimeControls["temporaryProgress"] = true; }
    cmd.prepare = [r, expected, connection, host, inputPrefix, network](ProcessCommand& out, const std::atomic_bool& cancel)->QString {
        const auto current = netplayIdentity(r, cancel);
        if (current.isEmpty() || (network && !sameMultiplayerGame(current, expected)))
            return "Your Doom files or runtime changed. Choose the game again.";
        if (network) {
            const auto c = flycast::CabinetConnection::read(connection);
            if (!c.valid() || (c.seat == 1) != host) return "The Doom lobby seats changed.";
        }
        const auto state = runtimepaths::data()
            + "/TrainerOS/doom/" + current["content"].toString() + (network ? "/network" : "/solo");
        if (!QDir().mkpath(state)) return "Couldn't prepare your Doom settings.";
        auto lock = std::make_shared<QLockFile>(state + "/session.lock"); lock->setStaleLockTime(0);
        if (!lock->tryLock()) return "This Doom session is already running.";
        QStringList args{"-I", bundleRoot() + "/launch.py", network ? "network" : "solo", r.contentPath,
                         current["content"].toString(), state, connection};
        args += inputPrefix;
        out.workingDirectory = state;
        if (network) {
            out.program = "/usr/bin/bwrap";
            out.arguments = {"--die-with-parent", "--unshare-net", "--bind", "/", "/", "--", "/usr/bin/python3"};
            out.arguments += args;
        } else { out.program = "/usr/bin/python3"; out.arguments = args; }
        const auto settled = out.settled;
        out.settled = [lock, settled](const ProcessOutcome& value) { if (settled) settled(value); lock->unlock(); };
        return {};
    };
    return cmd;
}
}
QString bundleRoot() { return runtimepaths::data() + "/TrainerOS/emulators/odamex"; }
QJsonObject netplayIdentity(const AdventureRegistration& r, const std::atomic_bool& cancel,
                           const std::function<void(const QString&)>& observe) {
    if (r.adventure.platformId != "doom" || r.adventure.adapterId != "odamex" || r.adventure.collectionOnly || !bundle(cancel)) return {};
    const auto c = content(r.contentPath, cancel);
    if (!hex(c["content"].toString())) return {};
    if (observe) for (const auto& p : c["dependencies"].toArray()) observe(p.toString());
    const auto protocol = QString::fromLatin1(QCryptographicHash::hash(QByteArray(Source) + '/' + Settings, QCryptographicHash::Sha256).toHex());
    return {{"id", "runtime.odamex.doom.v1"}, {"label", r.adventure.title.left(96)}, {"content", c["content"]},
            {"runtime", protocol}, {"settings", Settings}, {"players", 4}, {"lateJoin", false}, {"temporaryProgress", true},
            {"gameMode", c["mode"]}};
}
ProcessCommand command(const AdventureRegistration& r, const QJsonObject& expected, QString connection, bool host, const QStringList& prefix) {
    return launch(r, expected, connection, host, prefix, true);
}
ProcessCommand soloCommand(const AdventureRegistration& r, const QStringList& prefix) { return launch(r, {}, {}, true, prefix, false); }
}
