#include "LibraryMountWatcher.h"
#include <QFile>
#include <QStorageInfo>
#include <QDir>
#include <QFileInfo>
#include <algorithm>

namespace trainer {
namespace {
bool removablePath(const QString& path) {
    return path.startsWith("/run/media/") || path.startsWith("/media/")
        || path.startsWith("/mnt/") || path.startsWith("/var/mnt/");
}
QByteArray mountInfo() {QFile file("/proc/self/mountinfo");return file.open(QIODevice::ReadOnly)?file.readAll():QByteArray{};}
QString mountPath(QByteArray value) {
    value.replace("\\040"," ");value.replace("\\011","\t");value.replace("\\012","\n");value.replace("\\134","\\");
    return QString::fromUtf8(value);
}
}
QStringList libraryVolumesFromMountInfo(const QByteArray& info,bool localOnly) {
    QStringList result;
    for(const auto& line:info.split('\n')) {
        const auto fields=line.split(' ');const auto separator=fields.indexOf("-");
        if(fields.size()<6 || separator<6 || separator+2>=fields.size() || fields[separator+1]=="autofs")continue;
        const auto path=mountPath(fields[4]);
        if(removablePath(path) && (!localOnly || fields[separator+2].startsWith("/dev/")))result.append(path);
    }
    result.removeDuplicates();return result;
}
QStringList mountedLibraryVolumes() {
#ifdef Q_OS_LINUX
    return libraryVolumesFromMountInfo(mountInfo(),false);
#else
    QStringList roots;for(const auto& disk:QStorageInfo::mountedVolumes())if(disk.isValid()&&disk.isReady())roots.append(disk.rootPath());return roots;
#endif
}
bool libraryPathIsMounted(const QString& path,const QStringList& mounts) {
#ifdef Q_OS_LINUX
    if(removablePath(path))return std::any_of(mounts.cbegin(),mounts.cend(),[&](const QString& root){return path==root || path.startsWith(root+'/');});
#else
    Q_UNUSED(path);Q_UNUSED(mounts);
#endif
    return true;
}
QStringList mountedLibraryRoots(const QString& currentRoot) {
    QStringList roots;
    const auto add=[&](const QString& path) {
        const QFileInfo folder(path);
        if(folder.isDir() && folder.isReadable())roots.append(folder.canonicalFilePath());
    };
#ifdef Q_OS_LINUX
    const auto mounts=libraryVolumesFromMountInfo(mountInfo(),true);
#else
    const auto mounts=mountedLibraryVolumes();
#endif
    // Do not stat dormant automounts or wake network shares merely because a
    // card changed. Only inspect library folders on observed local mounts.
    for(const auto& mount:mounts) {
        if(currentRoot==mount || currentRoot.startsWith(mount+'/'))add(currentRoot);
        for(const auto& relative:{"Emulation/roms","roms","batocera/roms"})add(QDir(mount).filePath(relative));
    }
    roots.removeDuplicates();return roots;
}
LibraryMountWatcher::LibraryMountWatcher(QObject* parent):QObject(parent) {
    topology=[] {
#ifdef Q_OS_LINUX
        QByteArray result;
        for(const auto& line:mountInfo().split('\n'))if(!libraryVolumesFromMountInfo(line,true).isEmpty())result+=line+'\n';
        return result;
#else
        return mountedLibraryVolumes().join('\n').toUtf8();
#endif
    };
    timer_.setInterval(1000);
    connect(&timer_,&QTimer::timeout,this,&LibraryMountWatcher::poll);
}
void LibraryMountWatcher::start(const QString& startupRoot,bool scanConnected) {
    previous_=topology();initialized_=true;availabilityPending_=true;
    if(scanConnected && roots) {
        pending_=roots();pending_.removeDuplicates();pending_.removeAll(startupRoot);
    }
    timer_.start();
}
void LibraryMountWatcher::poll() {
    const auto current=topology();
    if(!initialized_ || current!=previous_) {
        previous_=current;initialized_=true;
        pending_=roots?roots():QStringList{};pending_.removeDuplicates();
        availabilityPending_=true;
        discoveryPending_=true;
        emit storageChanged();
    }
    if(availabilityPending_ && (!availabilityReady || availabilityReady())) {
        availabilityPending_=false;emit availabilityChanged();
    }
    if(discoveryPending_ && (!idle || idle())) {
        discoveryPending_=false;emit discoveryRequested();
    }
    if(!pending_.isEmpty() && (!idle || idle())) {
        const auto root=pending_.takeFirst();
        emit scanRequested(root);
    }
}
}
