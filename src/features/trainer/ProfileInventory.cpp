#include "ProfileInventory.h"

namespace trainer {
QVariantMap ProfileInventory::view() const {
    return {{"items",items_},{"index",index_},{"detail",detail_},{"preview",preview_},
        {"selected",items_.value(index_).toMap()},{"transfersAvailable",false}};
}
void ProfileInventory::setScope(QString owner,QString account) {
    if(owner_==owner&&account_==account)return;
    owner_=owner;account_=account;items_.clear();index_=0;detail_=preview_=false;emit changed();
}
void ProfileInventory::close() {detail_=false;emit changed();}
void ProfileInventory::activate(int index) {
    if(index<0||index>=items_.size())return;
    index_=index;detail_=true;emit changed();
}
void ProfileInventory::dispatch(Action action) {
    if(action==Action::Back) {
        if(detail_){detail_=false;emit changed();}else emit backRequested();
        return;
    }
    if(detail_) {
        if(action==Action::Up||action==Action::Down||action==Action::ScrollUp||action==Action::ScrollDown)
            emit scrollRequested(action==Action::Up||action==Action::ScrollUp?-64:64);
        return;
    }
    if(items_.isEmpty())return;
    if(action==Action::Confirm){activate(index_);return;}
    const int delta=action==Action::Left?-1:action==Action::Right?1:(action==Action::Up||action==Action::ScrollUp)?-3:(action==Action::Down||action==Action::ScrollDown)?3:0;
    if(delta){index_=qBound(0,index_+delta,int(items_.size())-1);emit changed();}
}
}
