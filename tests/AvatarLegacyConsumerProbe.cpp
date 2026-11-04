// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in integration probe: TAV1 descriptor, old Godot executable, old SDK project.
#include "platform/sdk/AvatarLegacy.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <QProcess>
#include <QDebug>
int main(int argc,char** argv) {
    QCoreApplication app(argc,argv);const auto args=app.arguments();if(args.size()!=4)return 2;
    QFile input(args[1]);if(!input.open(QIODevice::ReadOnly))return 2;
    const auto descriptor=QJsonDocument::fromJson(input.readAll()).object();
    std::shared_ptr<trainer::LegacyAvatarCache> cache;
    const auto old=trainer::legacyAvatar(descriptor,cache);
    if(old.contains("error")){qCritical()<<old;return 3;}
    const auto exported=old["glb"].toString();
    QTemporaryDir job;QFile file(job.filePath("descriptor.json"));
    if(!file.open(QIODevice::WriteOnly))return 4;file.write(QJsonDocument(old).toJson());file.close();
    QProcess child;child.setProcessChannelMode(QProcess::ForwardedChannels);
    child.start(args[2],{"--headless","--path",args[3],"--script","probe.gd","--","--descriptor="+file.fileName()});
    if(!child.waitForFinished(30000)){child.kill();child.waitForFinished();return 5;}
    const bool success=child.exitStatus()==QProcess::NormalExit&&child.exitCode()==0;
    cache.reset();if(QFile::exists(exported))return 6;
    qInfo()<<"Legacy Godot consumer and anonymous-resource cleanup:"<<success;
    return success?0:7;
}
