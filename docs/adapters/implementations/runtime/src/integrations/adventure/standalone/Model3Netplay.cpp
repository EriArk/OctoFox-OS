#include "platform/emulation/RuntimePaths.h"
// SPDX-License-Identifier: GPL-3.0-or-later
#include "Model3Netplay.h"
#include "CabinetConnection.h"
#include "core/model/GamePlayers.h"
#include "integrations/adventure/retroarch/RetroArchConfiguration.h"
#include <QDir>
#include <QCryptographicHash>
#include <QElapsedTimer>
#include <QLockFile>
#include <QProcess>
#include <QStandardPaths>

namespace trainer::model3 {
namespace {
constexpr auto Source="036af1c8d6640c5a60709c1f99144635ed82a184";
constexpr auto Settings="supermodel-native-ring-owned-v1";
bool hex(const QString& s){return QRegularExpression("^[a-f0-9]{64}$").match(s).hasMatch();}
QJsonObject bundle(const std::atomic_bool& cancel) {
    const auto root=bundleRoot(),canonical=QFileInfo(root).canonicalFilePath();
    QFile f(root+"/manifest.json");if(canonical.isEmpty()||!f.open(QIODevice::ReadOnly)||f.size()>16384)return {};
    const auto m=QJsonDocument::fromJson(f.readAll()).object();
    if(m["protocol"]!=1||m["source"]!=Source||m["settings"]!=Settings)return {};
    for(const auto& key:{"config","nvram"})if(!QFileInfo(m[key].toString()).isAbsolute())return {};
    const auto files=m["files"].toObject();
    const QStringList names{"bin/supermodel","bin/supermodel.real","lib/libSDL2_net-2.0.so.0","lib/libGLU.so.1","Config/Games.xml","Config/Supermodel.ini","content.py","model3_endpoint","stream_transport"};
    if(files.size()!=names.size())return {};
    for(const auto& n:names)if(!QFileInfo(root+'/'+n).canonicalFilePath().startsWith(canonical+'/')||!hex(files[n].toString())
        ||retroarch::fileDigest(root+'/'+n,256LL*1024*1024,cancel)!=files[n].toString())return {};
    for(const auto& n:{"bin/supermodel","bin/supermodel.real","model3_endpoint","stream_transport"})if(!QFileInfo(root+'/'+n).isExecutable())return {};
    if(!QFileInfo("/usr/bin/python3").isExecutable()||!QFileInfo("/usr/bin/bwrap").isExecutable())return {};
    return m;
}
QJsonObject helper(QStringList args,const std::atomic_bool& cancel) {
    QProcess p;p.setProcessEnvironment(runtimepaths::environment());p.setStandardErrorFile(QProcess::nullDevice());
    args.prepend(bundleRoot()+"/content.py");args.prepend("-I");p.start("/usr/bin/python3",args);
    if(!p.waitForStarted(3000))return {};
    QByteArray data;QElapsedTimer timer;timer.start();
    while(p.state()!=QProcess::NotRunning){p.waitForFinished(50);data+=p.readAllStandardOutput();
        if(cancel||timer.elapsed()>95000||data.size()>4096){p.kill();p.waitForFinished(2000);return {};}}
    data+=p.readAllStandardOutput();if(p.exitStatus()!=QProcess::NormalExit||p.exitCode()!=0||data.size()>4096)return {};
    return QJsonDocument::fromJson(data).object();
}
}
QString bundleRoot(){return runtimepaths::data()+"/TrainerOS/emulators/supermodel-link";}
QJsonObject netplayIdentity(const AdventureRegistration& r,const std::atomic_bool& cancel) {
    if(r.adventure.platformId!="model3"||r.adventure.adapterId!="supermodel"||r.adventure.collectionOnly||bundle(cancel).isEmpty())return {};
    const auto content=helper({"identity",bundleRoot(),r.contentPath},cancel);
    if(!hex(content["content"].toString())||content["link"]!=true)return {};
    const auto protocol=QString::fromLatin1(QCryptographicHash::hash(QByteArray(Source)+"/"+Settings,QCryptographicHash::Sha256).toHex());
    return {{"id","runtime.supermodel.link.v1"},{"label",r.adventure.title.left(96)},
        {"content",content["content"]},{"runtime",protocol},{"settings",Settings},{"players",4},
        {"set",content["name"]},{"lateJoin",false},{"privateProgress",true}};
}
ProcessCommand command(const AdventureRegistration& r,const QJsonObject& expected,QString connection,bool host,const QStringList& inputPrefix) {
    ProcessCommand cmd;cmd.emulatorRuntime=true;cmd.runtimeControls={{"kind","supermodel"},{"game",r.adventure.id},{"netplay",expected.toVariantMap()},{"temporaryProgress",false}};
    cmd.prepare=[r,expected,connection,host,inputPrefix](ProcessCommand& out,const std::atomic_bool& cancel)->QString {
        const auto current=netplayIdentity(r,cancel);
        if(!sameMultiplayerGame(current,expected))return "Your Model 3 game or runtime changed. Choose the game again.";
        const auto c=flycast::CabinetConnection::read(connection);
        if(!c.valid()||(c.seat==1)!=host)return "The Model 3 cabinet seats changed.";
        const auto m=bundle(cancel);if(m.isEmpty())return "The Model 3 package changed.";
        const auto home=runtimepaths::data()+"/TrainerOS/model3-link/"+current["content"].toString();
        if(!QDir().mkpath(home))return "Couldn't prepare your cabinet settings.";
        auto lock=std::make_shared<QLockFile>(home+"/session.lock");lock->setStaleLockTime(0);
        if(!lock->tryLock())return "Your Model 3 cabinet is already running.";
        const auto directory=home+"/seat"+QString::number(c.seat);
        if(helper({"prepare",bundleRoot(),directory,m["config"].toString(),m["nvram"].toString(),current["set"].toString()},cancel)["ready"]!=true)
            return "Couldn't prepare your own cabinet settings.";
        out.program="/usr/bin/bwrap";out.workingDirectory=directory;
        out.arguments={"--die-with-parent","--unshare-net","--bind","/","/","--",bundleRoot()+"/model3_endpoint",connection,"/usr/bin/env","-u","TRAINEROS_SUPERMODEL_INSPECT"};
        out.arguments+=inputPrefix;
        out.arguments<<bundleRoot()+"/bin/supermodel"<<"-fullscreen"<<"-net"<<"-simulate-netboard"
            <<("-game-xml-file="+bundleRoot()+"/Config/Games.xml")<<("-port-in="+QString::number(19700+c.seat))
            <<("-port-out="+QString::number(19700+c.seat%c.players+1))<<"-address-out=127.0.0.1"<<r.contentPath;
        const auto settled=out.settled;out.settled=[lock,settled](const ProcessOutcome& value){if(settled)settled(value);lock->unlock();};
        return {};
    };return cmd;
}
}
