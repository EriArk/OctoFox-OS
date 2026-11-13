#pragma once
#include "core/input/Action.h"
#include <QObject>
#include <QVariantMap>
#include <QVariantList>

namespace trainer {
// Profile-owned presentation. Save transfers and server custody are not enabled.
// Only isolated fixtures supply entries until an authoritative provider exists.
class ProfileInventory final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap view READ view NOTIFY changed)
public:
    explicit ProfileInventory(QObject* parent=nullptr):QObject(parent){}
    QVariantMap view() const;
    void setScope(QString owner,QString account);
    void close();
    void dispatch(Action action);
    Q_INVOKABLE void activate(int index);
signals:
    void changed();
    void backRequested();
    void scrollRequested(int delta);
private:
    friend class ProfileInventoryFixture;
    QString owner_,account_;
    QVariantList items_;
    int index_=0;
    bool detail_=false,preview_=false;
};
}
