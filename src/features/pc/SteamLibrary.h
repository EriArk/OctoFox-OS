#pragma once
#include "core/repository/LibraryRepository.h"
#include <QProcess>
#include <QTimer>
#include <QJsonArray>

namespace trainer {
// Read-only external discovery; writes only TrainerOS registrations. Serial
// updates preserve AppID history and cannot erase an unplugged library.
class SteamLibrary final : public QObject {
    Q_OBJECT
public:
    explicit SteamLibrary(LibraryRepository&, QObject* parent=nullptr);
    ~SteamLibrary() override;
    bool busy() const { return busy_; }
    bool writing() const { return busy_ && !games_.isEmpty(); }
    std::function<bool()> canApply;
    void scan();
    void reconcile(const QJsonArray& games);
signals:
    void changed();
    void notice(QString);
private:
    void next();
    LibraryRepository& library_;
    QProcess process_;
    QTimer deadline_;
    QByteArray output_;
    QJsonArray games_;
    int index_=0;
    bool busy_=false;
    QString lastWarning_;
};
}
