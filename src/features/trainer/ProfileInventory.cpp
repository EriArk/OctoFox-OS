#include "ProfileInventory.h"
#include <algorithm>
#include <QJsonArray>
#include <QPointer>
#include <QRegularExpression>
#include <QSet>
#include <QUuid>

namespace trainer {
QVariantMap ProfileInventory::view() const {
    return {{"items",visible_},{"index",index_},{"control",control_},{"preview",preview_},
        {"selected",visible_.value(index_).toMap()},{"transfersAvailable",false},
        {"search",search_},{"filter",QStringList{"All","Stored","On sale"}[filter_]},
        {"sort",QStringList{"Recent","Name","Level"}[sort_]},{"total",preview_?items_.size():total_},
        {"loaded",items_.size()},{"state",state_},{"message",message_},{"busy",busy_},
        {"hasMore",!next_.isEmpty()},{"connected",connected_}};
}
void ProfileInventory::rebuild() {
    const auto selected=visible_.value(index_).toMap()["id"].toString();
    visible_.clear();
    for(const auto& item:items_) {
        const auto row=item.toMap();
        if(filter_==1&&row["state"]=="listed")continue;
        if(filter_==2&&row["state"]!="listed")continue;
        if(!search_.isEmpty()&&!row["title"].toString().contains(search_,Qt::CaseInsensitive)
            &&!row["game"].toString().contains(search_,Qt::CaseInsensitive))continue;
        visible_.append(item);
    }
    if(sort_)std::stable_sort(visible_.begin(),visible_.end(),[this](const QVariant& a,const QVariant& b){
        const auto left=a.toMap(),right=b.toMap();
        return sort_==1?QString::compare(left["title"].toString(),right["title"].toString(),Qt::CaseInsensitive)<0:
            left["level"].toInt()>right["level"].toInt();
    });
    index_=0;
    for(int i=0;i<visible_.size();++i)if(visible_[i].toMap()["id"]==selected){index_=i;break;}
    emit changed();
}
void ProfileInventory::setScope(QString owner,QString account,bool connected) {
    connected=connected&&!account.isEmpty()&&!owner.isEmpty();
    if(owner_==owner&&account_==account&&connected_==connected)return;
    const bool identityChanged=owner_!=owner||account_!=account;
    owner_=owner;account_=account;items_.clear();visible_.clear();
    if(identityChanged){search_.clear();filter_=sort_=0;}
    ++generation_;connected_=connected;busy_=false;next_.clear();revision_.clear();total_=0;
    state_=account.isEmpty()?"signed_out":connected?"idle":"offline";message_.clear();
    index_=0;control_=-1;preview_=searchPending_=false;emit changed();
    if(open_&&connected_)refresh();
}
void ProfileInventory::open() {open_=true;control_=-1;searchPending_=false;if(!preview_)refresh();else emit changed();}
void ProfileInventory::close() {open_=false;++generation_;busy_=false;control_=-1;searchPending_=false;if(state_=="loading")state_="idle";emit changed();}
void ProfileInventory::refresh() {fetch(false);}
void ProfileInventory::loadMore() {if(!next_.isEmpty())fetch(true);}
void ProfileInventory::fetch(bool more) {
    if(busy_||preview_||!open_||!connected_||!read)return;
    busy_=true;state_="loading";message_.clear();const auto generation=++generation_;
    const auto cursor=more?next_:QString(),revision=more?revision_:QString();emit changed();
    QPointer<ProfileInventory> guard(this);
    read(cursor,revision,[guard,generation,more](int status,QJsonObject result){
        if(!guard||generation!=guard->generation_)return;
        auto& self=*guard;self.busy_=false;
        if(status==200&&self.adopt(result,more)){self.state_="ready";self.message_.clear();self.rebuild();return;}
        if(!more||status==401||status==409){self.items_.clear();self.visible_.clear();self.next_.clear();self.revision_.clear();self.total_=0;self.index_=0;}
        self.state_=status==401?"signed_out":status==404?"unavailable":"error";
        self.message_=status==409?"Inventory changed. Refresh to load it again.":
            status==401?"Connect your TrainerOS account to view your items.":
            status==404?"This server has not enabled the inventory yet.":
            more?"Could not load more items. Your loaded items are still shown; try again.":
            "Could not load your inventory. Check the connection and retry.";
        emit self.changed();
    });
}
bool ProfileInventory::adopt(const QJsonObject& result,bool more) {
    const auto integer=[](const QJsonValue& v,int min,int max){return v.isDouble()&&v.toDouble()>=min&&v.toDouble()<=max&&v.toDouble()==v.toInt(-1);};
    const auto text=[](const QJsonValue& v,int min,int max){return v.isString()&&v.toString().size()>=min&&v.toString().size()<=max;};
    static const QRegularExpression number("^(0|[1-9][0-9]{0,18})$"),key("^[a-z0-9][a-z0-9._-]{0,63}$");
    if(result["version"]!=1||result["player_id"].toString()!=account_||!result["items"].isArray()
        ||!result["revision"].isString()||!number.match(result["revision"].toString()).hasMatch()
        ||!integer(result["total"],0,1000000)||result["transfers_available"]!=false)return false;
    if(more&&(result["revision"]!=revision_||result["total"].toInt()!=total_))return false;
    const auto rows=result["items"].toArray();
    if(rows.size()>60||(!result["next"].isNull()&&!result["next"].isString()))return false;
    const auto next=result["next"].toString();
    if(!next.isEmpty()) {
        bool ok=false;const auto n=next.toLongLong(&ok);
        if(!ok||n<=0||QString::number(n)!=next||rows.size()!=60||(more&&n>=next_.toLongLong()))return false;
    } else if(!result["next"].isNull())return false;
    QVariantList incoming;QSet<QString> ids;
    if(more)for(const auto& row:items_)ids.insert(row.toMap()["id"].toString());
    for(const auto& value:rows) {
        if(!value.isObject())return false;
        const auto row=value.toObject(),p=row["presentation"].toObject();const auto id=row["id"].toString();
        if(QUuid(id).isNull()||ids.contains(id)||!integer(row["payload_version"],1,2147483647)
            ||!key.match(row["game_id"].toString()).hasMatch()||!key.match(row["adapter_id"].toString()).hasMatch()
            ||!key.match(row["kind"].toString()).hasMatch()||!row["actions"].isArray()||!row["actions"].toArray().isEmpty()
            ||(row["state"]!="stored"&&row["state"]!="listed")||!text(p["title"],1,96)||!text(p["game"],1,128)
            ||!text(p["subtitle"],0,32)||!QStringList{"inventory","star","shield","shop","gamepad","map"}.contains(p["icon"].toString())
            ||(!p["level"].isUndefined()&&!integer(p["level"],0,999999))||!p["facts"].isArray()||p["facts"].toArray().size()>16)return false;
        for(const auto& fact:p["facts"].toArray())if(!fact.isObject()||!text(fact.toObject()["label"],1,32)||!text(fact.toObject()["value"],0,128))return false;
        ids.insert(id);
        incoming.append(QVariantMap{{"id",id},{"title",p["title"].toString()},{"game",p["game"].toString()},
            {"subtitle",p["subtitle"].toString()},{"icon",p["icon"].toString()},{"level",p["level"].toInt()},
            {"facts",p["facts"].toArray().toVariantList()},{"state",row["state"].toString()}});
    }
    const auto loaded=(more?items_.size():0)+incoming.size();const auto total=result["total"].toInt();
    if(loaded>total||(next.isEmpty()&&loaded!=total)||(!next.isEmpty()&&loaded>=total))return false;
    if(more)items_.append(incoming);else items_=incoming;
    total_=total;next_=next;revision_=result["revision"].toString();return true;
}
void ProfileInventory::activate(int index) {
    if(index<0||index>=visible_.size())return;
    if(index_==index&&control_==-1)return;
    index_=index;control_=-1;emit changed();
}
void ProfileInventory::control(int index) {
    if(index<0||index>4)return;
    control_=index;
    if(index==3){loadMore();return;}
    if(index==4){refresh();return;}
    if(index==0){searchPending_=true;searchOwner_=owner_;searchAccount_=account_;emit changed();emit searchRequested(search_);}
    else {if(index==1)filter_=(filter_+1)%3;else sort_=(sort_+1)%3;rebuild();}
}
void ProfileInventory::applySearch(QString text) {
    if(!searchPending_||searchOwner_!=owner_||searchAccount_!=account_)return;
    searchPending_=false;control_=-1;search_=text.trimmed().left(64);rebuild();
}
void ProfileInventory::clearSearch() {searchPending_=false;search_.clear();rebuild();}
void ProfileInventory::dispatch(Action action) {
    if(action==Action::Back){emit backRequested();return;}
    if(action==Action::ChangeView){control(0);return;}
    if(action==Action::ScrollUp||action==Action::ScrollDown){emit scrollRequested(action==Action::ScrollUp?-54:54);return;}
    if(action==Action::LocalAction){control_=control_>=0?-1:0;emit changed();return;}
    if(control_>=0) {
        if(action==Action::Confirm){control(control_);return;}
        if(action==Action::Down)control_=-1;
        else if(action==Action::Left||action==Action::Right)control_=qBound(0,control_+(action==Action::Left?-1:1),4);
        emit changed();return;
    }
    if(action==Action::Up&&index_<6){control_=0;emit changed();return;}
    if(visible_.isEmpty())return;
    const int delta=action==Action::Left?-1:action==Action::Right?1:action==Action::Up?-6:action==Action::Down?6:0;
    if(delta)activate(qBound(0,index_+delta,int(visible_.size())-1));
}
}
