#pragma once
#include "core/input/Action.h"
#include <QObject>
#include <QVariantMap>
#include <QVariantList>

namespace trainer {
// Profile presentation only. Authoritative custody and save transfers remain closed.
class ProfileInventory final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap view READ view NOTIFY changed)
public:
    explicit ProfileInventory(QObject* parent=nullptr):QObject(parent){}
    QVariantMap view() const;
    void setScope(QString owner,QString account);
    void close();
    void dispatch(Action action);
    void applySearch(QString text);
    Q_INVOKABLE void activate(int index);
    Q_INVOKABLE void control(int index);
    Q_INVOKABLE void clearSearch();
signals:
    void changed();
    void backRequested();
    void scrollRequested(int delta);
    void searchRequested(QString initial);
private:
    friend class ProfileInventoryFixture;
    void rebuild();
    QString owner_,account_,search_,searchOwner_,searchAccount_;
    QVariantList items_,visible_;
    int index_=0,control_=-1,filter_=0,sort_=0;
    bool preview_=false,searchPending_=false;
};
}
