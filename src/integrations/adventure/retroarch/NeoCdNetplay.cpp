// SPDX-License-Identifier: GPL-3.0-or-later
#include "NeoCdNetplay.h"
#include "RetroArchConfiguration.h"
#include "RetroArchDisc.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QCryptographicHash>
namespace trainer::retroarch {
namespace {
constexpr auto Source="b1e04c738cb48a1dae0574b8877f6a116d270ca1";
constexpr auto ProfileSettings="neocd-two-pad-private-bios-aslr-v1";
QString hash(const QJsonObject& value) {
    return QString::fromLatin1(QCryptographicHash::hash(QJsonDocument(value).toJson(QJsonDocument::Compact),QCryptographicHash::Sha256).toHex());
}
QString core(const RetroArchInstallation& i,const std::atomic_bool& cancel,NetplayDigestCache* cache) {
    const auto path=i.cores.value("neocd_netplay");
    if(path.isEmpty())return {};
    const auto manifest=QFileInfo(path).dir().filePath("manifest.json");
    if(cache){cache->observe(path);cache->observe(manifest);}
    QFile f(manifest);if(!f.open(QIODevice::ReadOnly)||f.size()>4096)return {};
    const auto m=QJsonDocument::fromJson(f.readAll()).object();
    if(m["source"]!=Source||m["settings"]!=ProfileSettings||m["protocol"]!=1)return {};
    const auto digest=fileDigest(path,64*1024*1024,cancel);
    return !digest.isEmpty()&&m["core"]==digest?digest:QString();
}
QJsonObject firmware(const RetroArchInstallation& i,const std::atomic_bool& cancel,NetplayDigestCache* cache) {
    const auto files=i.discFirmware.value("neogeocd");
    const auto root=configuredPath(readSettings(i.configFile),"system_directory");
    if(cache)for(auto it=files.begin();it!=files.end();++it)cache->observe(QDir(root).filePath(it.key()));
    // The private system directory contains exactly this verified set. The core
    // cannot discover an additional BIOS beside the ordinary installation.
    if(!verifiedDiscFirmware(i,"neogeocd",cancel))return {};
    return files;
}
}
QJsonObject neoCdIdentity(const AdventureRegistration& r,const RetroArchInstallation& i,
                         const std::atomic_bool& cancel,NetplayDigestCache* cache) {
    const auto observe=[cache](const QString& p){if(cache)cache->observe(p);};
    observe(r.contentPath);observe(i.configFile);observe(i.runtimeFile);
    if(r.adventure.platformId!="neogeocd"||r.integrationConfig["core"]!="neocd"||
       !validateDiscContent(r.contentPath,cancel,observe).isEmpty())return {};
    const auto coreHash=core(i,cancel,cache),runtime=fileDigest(i.runtimeFile,512LL*1024*1024,cancel);
    const auto bios=firmware(i,cancel,cache);
    if(coreHash.isEmpty()||runtime.isEmpty()||bios.isEmpty())return {};
    // Content hashing (including every CUE track) stays in the shared reader.
    return {{"id","runtime.retroarch.neogeocd.neocd.v1"},{"label",r.adventure.title.left(96)},
        {"settings",ProfileSettings},{"players",2},{"core",coreHash},{"runtime",runtime},
        {"firmware",hash(bios)},{"lateJoin",false}};
}
QString prepareNeoCd(ProcessCommand& command,const RetroArchInstallation& i,const QJsonObject& identity,
                     const QString& directory,const std::atomic_bool& cancel) {
    if(core(i,cancel,nullptr)!=identity["core"].toString())return "Your Neo Geo CD runtime changed. Prepare the game again.";
    const auto files=firmware(i,cancel,nullptr);
    if(files.isEmpty()||hash(files)!=identity["firmware"].toString())return "Your Neo Geo CD BIOS changed. Prepare the game again.";
    const auto source=configuredPath(readSettings(i.configFile),"system_directory");
    QJsonObject copied;
    for(auto it=files.begin();it!=files.end();++it) {
        const auto target=directory+"/system/"+it.key();
        if(!QDir().mkpath(QFileInfo(target).absolutePath())||!QFile::copy(QDir(source).filePath(it.key()),target))
            return "Couldn't prepare the private Neo Geo CD BIOS.";
        copied[it.key()]=fileDigest(target,1024*1024,cancel);
    }
    if(cancel||copied!=files)return "Your Neo Geo CD BIOS changed during preparation.";
    const auto index=command.arguments.indexOf("--libretro");
    if(index<0||index+1>=command.arguments.size())return "The Neo Geo CD launch route changed.";
    command.arguments[index+1]=i.cores.value("neocd_netplay");
    return {};
}
}
