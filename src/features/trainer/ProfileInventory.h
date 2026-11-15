#pragma once
#include "core/input/Action.h"
#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QJsonObject>
#include <functional>

namespace trainer {
// Private server projection. Custody writes and save transfers remain closed.
class ProfileInventory final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap view READ view NOTIFY changed)
public:
    explicit ProfileInventory(QObject* parent=nullptr):QObject(parent){}
    QVariantMap view() const;
    using Reply=std::function<void(int,QJsonObject)>;
    std::function<void(QString,QString,Reply)> read;
    void setScope(QString owner,QString account,bool connected=true);
    void open();
    void close();
    void dispatch(Action action);
    void applySearch(QString text);
    Q_INVOKABLE void activate(int index);
    Q_INVOKABLE void control(int index);
    Q_INVOKABLE void clearSearch();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void loadMore();
signals:
    void changed();
    void backRequested();
    void scrollRequested(int delta);
    void searchRequested(QString initial);
private:
    friend class ProfileInventoryFixture;
    void rebuild();
    void fetch(bool more);
    bool adopt(const QJsonObject& result,bool more);
    QString owner_,account_,search_,searchOwner_,searchAccount_;
    QVariantList items_,visible_;
    int index_=0,control_=-1,filter_=0,sort_=0;
    bool preview_=false,searchPending_=false;
    bool open_=false,connected_=false,busy_=false;
    quint64 generation_=0;
    QString state_="signed_out",message_,next_,revision_;
    int total_=0;
};
}
