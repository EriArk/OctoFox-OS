#pragma once
#include <QObject>
#include <QTimer>
#include <QStringList>
#include <functional>

namespace trainer {
QStringList mountedLibraryRoots(const QString& currentRoot);
// Mount changes, not navigation, schedule discovery. Queued work waits for the
// existing library/game owners; repeated changes coalesce to the latest mounts.
class LibraryMountWatcher final : public QObject {
    Q_OBJECT
public:
    explicit LibraryMountWatcher(QObject* parent = nullptr);
    void start(const QString& startupRoot = {}, bool scanConnected = true);
    void poll();
    std::function<QByteArray()> topology;
    std::function<QStringList()> roots;
    std::function<bool()> idle;
    std::function<bool()> availabilityReady;
signals:
    void storageChanged();
    void availabilityChanged();
    void discoveryRequested();
    void scanRequested(const QString& root);
private:
    QTimer timer_;
    QByteArray previous_;
    QStringList pending_;
    bool initialized_ = false;
    bool availabilityPending_ = false;
    bool discoveryPending_ = false;
};
}
