// SPDX-License-Identifier: GPL-3.0-or-later
#include "NgpcNetplay.h"
#include "CabinetConnection.h"
#include "integrations/adventure/CartridgeContent.h"
#include "integrations/adventure/retroarch/RetroArchConfiguration.h"
#include "core/model/GamePlayers.h"
#include <QCryptographicHash>
#include <QDir>
#include <QJsonDocument>
#include <QLockFile>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryDir>

namespace trainer::ngpc {
namespace {
constexpr auto Source="d0acb0874cc07735d7fa978539bb2471b2c1e71a";
constexpr auto Settings="ngpc-mirror-own-flash-v1";
QString hash(const QByteArray& bytes){return QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex());}
QJsonObject bundle(const std::atomic_bool& cancel,const std::function<void(const QString&)>& observe) {
    auto root=bundleRoot();QFile f(root+"/manifest.json");if(observe)observe(f.fileName());
    if(!f.open(QIODevice::ReadOnly)||f.size()>32768)return {};
    auto m=QJsonDocument::fromJson(f.readAll()).object();
    if(m["protocol"]!=1||m["source"]!=Source||m["settings"]!=Settings)return {};
    const auto valid=[](QString v){return QRegularExpression("^[0-9a-f]{64}$").match(v).hasMatch();};
    if(!valid(m["runtime"].toString())||!QRegularExpression("^[0-9]+:p[0-9a-f]{16}$").match(m["fingerprint"].toString()).hasMatch()||
       m["runtime"]!=hash(QByteArray(Source)+'/'+Settings+'/'+m["fingerprint"].toString().toLatin1()))return {};
    QStringList required{"core.so","frontend.so","font.ttf","bios_hle.bin","upstream.zip","launch.py","state.py","channel.py","stream_transport"};
    const auto files=m["files"].toObject();if(files.size()<required.size()||files.size()>64)return {};
    for(const auto& name:required)if(!files.contains(name))return {};
    const auto canonical=QFileInfo(root).canonicalFilePath();if(canonical.isEmpty())return {};
    for(auto it=files.begin();it!=files.end();++it) {
        const auto name=it.key(),path=root+'/'+name;if(observe)observe(path);
        if((!required.contains(name)&&!QRegularExpression("^lib/[A-Za-z0-9_.+-]+$").match(name).hasMatch())||
           !QFileInfo(path).canonicalFilePath().startsWith(canonical+'/')||!valid(it.value().toString())||
           retroarch::fileDigest(path,128LL*1024*1024,cancel)!=it.value().toString())return {};
    }
    if(!QFileInfo(root+"/stream_transport").isExecutable()||!QFileInfo("/usr/bin/python3").isExecutable())return {};
    return m;
}
}
QString bundleRoot(){return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)+"/TrainerOS/emulators/ngpc";}
QJsonObject netplayIdentity(const AdventureRegistration& r,const std::atomic_bool& cancel,const std::function<void(const QString&)>& observe) {
    if(!QStringList{"ngp","ngpc"}.contains(r.adventure.platformId)||r.adventure.collectionOnly)return {};
    if(observe)observe(r.contentPath);
    const auto package=bundle(cancel,observe);if(package.isEmpty())return {};
    const auto image=cartridge::read(r.contentPath,r.adventure.platformId,cancel);
    if(image.bytes.size()<64||image.bytes.size()>4*1024*1024)return {};
    return {{"id","runtime.ngpc.link.v1"},{"label",r.adventure.title.left(96)},{"content",image.digest()},
        {"runtime",package["runtime"]},{"settings",Settings},{"players",2},{"lateJoin",false}};
}
ProcessCommand command(const AdventureRegistration& r,const QJsonObject& expected,QString connection,bool host,QString owner,const QStringList& prefix) {
    ProcessCommand cmd;cmd.runtimeControls={{"kind","ngpc"},{"game",r.adventure.id},{"netplay",expected.toVariantMap()}};
    cmd.prepare=[=](ProcessCommand& out,const std::atomic_bool& cancel)->QString {
        const auto current=netplayIdentity(r,cancel);
        if(owner.isEmpty()||!sameMultiplayerGame(current,expected))return "Your Pocket game or runtime changed. Choose it again.";
        const auto c=flycast::CabinetConnection::read(connection);
        if(!c.valid()||c.players!=2||(c.seat==1)!=host)return "The Pocket lobby seats changed.";
        const auto state=QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/ngpc-link/"+hash(owner.toUtf8())+'/'+current["content"].toString();
        if(!QDir().mkpath(state))return "Couldn't prepare your linked Pocket saves.";
        auto lock=std::make_shared<QLockFile>(state+"/session.lock");lock->setStaleLockTime(0);
        if(!lock->tryLock())return "This linked Pocket game is already running.";
        auto temporary=std::make_shared<QTemporaryDir>(QDir::tempPath()+"/traineros-ngpc-XXXXXX");
        const auto image=cartridge::read(r.contentPath,r.adventure.platformId,cancel);
        if(!temporary->isValid()||image.digest()!=current["content"].toString())return "The Pocket cartridge changed during preparation.";
        const auto rom=temporary->filePath("game.ngc");QSaveFile f(rom);
        if(!f.open(QIODevice::WriteOnly)||f.write(image.bytes)!=image.bytes.size()||!f.commit())return "Couldn't prepare the Pocket cartridge.";
        QStringList args{"-I",bundleRoot()+"/launch.py",rom,current["content"].toString(),state,connection};
        out.program="/usr/bin/env";
        out.arguments={"TRAINEROS_NGPC_MANAGED=1","LD_LIBRARY_PATH="+bundleRoot()+"/lib"};
        out.arguments+=prefix;out.arguments<<"/usr/bin/python3";out.arguments+=args;
        out.workingDirectory=state;
        out.finalize=[](const ProcessOutcome& value)->QString {
            return value.started&&(value.crashed||value.exitCode!=0)?QString("Pocket Link ended before a clean exit. Your previous saved progress is kept."):QString();
        };
        const auto settled=out.settled;
        out.settled=[lock,temporary,settled](const ProcessOutcome& value){if(settled)settled(value);lock->unlock();};
        return {};
    };
    return cmd;
}
}
