#pragma once
#include "core/repository/LibraryRepository.h"
#include "integrations/adventure/AdventureAdapter.h"
#include <QThread>

namespace trainer {
// Silent recovery for an installed game without a ready binding. One launch
// request owns verification, optional binding repair and the normal launch.
class LaunchPreparation final : public QObject {
    Q_OBJECT
public:
    LaunchPreparation(LibraryRepository& library, AdventureAdapter& adapter, QObject* parent=nullptr)
        : QObject(parent), library_(library), adapter_(adapter) {}
    ~LaunchPreparation() override;
    bool busy() const { return busy_; }
    bool cancelling() const { return cancelling_; }
    QString adventureId() const { return adventureId_; }
    QString stage() const { return cancelling_ ? "Cancelling…" : stage_; }
    void launch(const QString& id);
    void check(const QString& id);
    // Snapshot copied on the GUI thread; invoked only for the selected game on the worker.
    std::function<QVariantMap(const AdventureRegistration&)> requirements;

    void cancel();
signals:
    void changed();
    void libraryChanged();
    void messageRequested(const QString& message);
    void checked(QString id, QVariantMap result);
    void preparationRequired(QString id, QVariantMap result);
private:
    void begin(const QString& id, bool play);
    void fail(const QString&, const QString& repair = "software");
    LibraryRepository& library_;
    AdventureAdapter& adapter_;
    QThread* worker_=nullptr;
    bool busy_=false;
    bool cancelling_=false, playing_=true;
    QString adventureId_,stage_;
};
}
