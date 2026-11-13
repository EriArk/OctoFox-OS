#include "ProfileInventory.h"
#include <algorithm>

namespace trainer {
QVariantMap ProfileInventory::view() const {
    return {{"items",visible_},{"index",index_},{"control",control_},{"preview",preview_},
        {"selected",visible_.value(index_).toMap()},{"transfersAvailable",false},
        {"search",search_},{"filter",QStringList{"All","Stored","On sale"}[filter_]},
        {"sort",QStringList{"Recent","Name","Level"}[sort_]},{"total",items_.size()}};
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
void ProfileInventory::setScope(QString owner,QString account) {
    if(owner_==owner&&account_==account)return;
    owner_=owner;account_=account;items_.clear();visible_.clear();search_.clear();
    index_=filter_=sort_=0;control_=-1;preview_=searchPending_=false;emit changed();
}
void ProfileInventory::close() {control_=-1;searchPending_=false;emit changed();}
void ProfileInventory::activate(int index) {
    if(index<0||index>=visible_.size())return;
    if(index_==index&&control_==-1)return;
    index_=index;control_=-1;emit changed();
}
void ProfileInventory::control(int index) {
    if(index<0||index>2)return;
    control_=index;
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
        else if(action==Action::Left||action==Action::Right)control_=qBound(0,control_+(action==Action::Left?-1:1),2);
        emit changed();return;
    }
    if(action==Action::Up&&index_<6){control_=0;emit changed();return;}
    if(visible_.isEmpty())return;
    const int delta=action==Action::Left?-1:action==Action::Right?1:action==Action::Up?-6:action==Action::Down?6:0;
    if(delta)activate(qBound(0,index_+delta,int(visible_.size())-1));
}
}
