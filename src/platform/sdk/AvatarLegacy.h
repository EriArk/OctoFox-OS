// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "../../../sdk/qt/AvatarResource.h"
#include <QJsonObject>
#include <QTemporaryDir>
#include <QDir>
#include <QHash>
#ifdef Q_OS_LINUX
#include <sys/vfs.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#endif

namespace trainer {
struct LegacyAvatarCache {
    QTemporaryDir directory{"/dev/shm/trainer-avatar-sdk-XXXXXX"};
    QHash<QString,std::shared_ptr<QFile>> handles;
};
// Compatibility for released SDK v1 games. Never fall back to disk-backed /tmp.
// Anonymous sealed memfd storage dies even on host crash. The legacy .glb path
// is only a symlink to that process's descriptor, not another plaintext copy.
inline QJsonObject legacyAvatar(const QJsonObject& descriptor,std::shared_ptr<LegacyAvatarCache>& cache) {
    if(descriptor["format"]!="tav1")return descriptor;
#ifdef Q_OS_LINUX
    struct statfs fs{};
    if(statfs("/dev/shm",&fs)!=0||fs.f_type!=0x01021994)return {{"error","avatar_consumer_update_required"}};
    if(!cache)cache=std::make_shared<LegacyAvatarCache>();
    if(!cache->directory.isValid())return {{"error","avatar_cache_unavailable"}};
    const auto expected=descriptor["sha256"].toString().toLatin1();
    if(expected.size()!=64||expected!=QByteArray::fromHex(expected).toHex())return {{"error","avatar_cache_invalid"}};
    const auto path=cache->directory.filePath(QString::fromLatin1(expected)+".glb");
    if(cache->handles.contains(path)) {
        auto result=descriptor;result["format"]="glb";result["glb"]=path;result["preview"]=path;return result;
    }
    const auto bytes=AvatarResource::read(descriptor["glb"].toString());
    const auto hash=QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex();
    if(bytes.isEmpty()||hash!=descriptor["sha256"].toString().toLatin1())return {{"error","avatar_cache_invalid"}};
    const int fd=memfd_create("trainer-avatar",MFD_CLOEXEC|MFD_ALLOW_SEALING);
    if(fd<0)return {{"error","avatar_cache_unavailable"}};
    auto file=std::make_shared<QFile>();
    if(!file->open(fd,QIODevice::ReadWrite,QFileDevice::AutoCloseHandle)){::close(fd);return {{"error","avatar_cache_unavailable"}};}
    if(fchmod(fd,0600)!=0||file->write(bytes)!=bytes.size()||!file->flush()||
        fcntl(fd,F_ADD_SEALS,F_SEAL_WRITE|F_SEAL_GROW|F_SEAL_SHRINK|F_SEAL_SEAL)!=0)return {{"error","avatar_cache_write_failed"}};
    const auto target=QString("/proc/%1/fd/%2").arg(getpid()).arg(fd).toUtf8();
    if(::symlink(target.constData(),QFile::encodeName(path).constData())!=0)return {{"error","avatar_cache_write_failed"}};
    cache->handles.insert(path,file);
    const auto files=QDir(cache->directory.path()).entryInfoList({"*.glb"},QDir::Files,QDir::Time);
    for(int i=2;i<files.size();++i){QFile::remove(files[i].absoluteFilePath());cache->handles.remove(files[i].absoluteFilePath());}
    auto result=descriptor;result["format"]="glb";result["glb"]=path;result["preview"]=path;return result;
#else
    return {{"error","avatar_consumer_update_required"}};
#endif
}
}
