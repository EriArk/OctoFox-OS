#include "LibraryMountWatcher.h"
#include <QFile>
#include <QStorageInfo>

namespace trainer {
LibraryMountWatcher::LibraryMountWatcher(QObject* parent):QObject(parent) {
    topology=[] {
#ifdef Q_OS_LINUX
        QFile mounts("/proc/self/mountinfo");
        if(mounts.open(QIODevice::ReadOnly)) {
            QByteArray result;
            for(const auto& line:mounts.readAll().split('\n')) {
                const auto fields=line.split(' ');
                if(fields.size()<6)continue;
                const auto path=fields[4];
                if(path.startsWith("/run/media/") || path.startsWith("/media/")
                    || path.startsWith("/mnt/") || path.startsWith("/var/mnt/"))result+=line+'\n';
            }
            return result;
        }
#endif
        QByteArray result;
        for(const auto& disk:QStorageInfo::mountedVolumes())
            result+=disk.device()+'\0'+disk.rootPath().toUtf8()+'\0';
        return result;
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
