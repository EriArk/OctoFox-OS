#include "BazaarCatalogue.h"
#include "features/accounts/BackendAccount.h"
#include <QJsonArray>
#include <cmath>

namespace trainer {
void BazaarCatalogue::setScroll(qreal value) {
    if(!std::isfinite(value))return;
    value=qBound(0.0,value,1000000.0);
    if(qFuzzyCompare(scroll_+1,value+1))return;
    scroll_=value;emit scrollChanged();
}

int BazaarCatalogue::selectedIndex() const {
    for(int i=0;i<visible_.size();++i)
        if(selection_=="room:"+visible_[i].toMap().value("id").toString())return i;
    return -1;
}
void BazaarCatalogue::setOwner(QString owner) {
    if(owner_==owner)return;
    ++accessGeneration_;moderating_=false;blocks_.clear();accessTarget_={};accessNext_.clear();formReturn_.clear();
    ++generation_;loading_=saving_=fixture_=false;draft_={};own_={};next_.clear();message_.clear();textField_.clear();
    owner_=owner;all_.clear();realms_.clear();favorites_.clear();search_.clear();lastRoom_.clear();
    selection_="official";favoritesOnly_=false;setScroll(0);dialog_.clear();realmIndex_=0;
    status_=connection_=="connected" ? "Player bazaars are not available yet." :
        connection_=="connecting" ? "Connecting…" : "Sign in to browse player bazaars.";
    rebuild();
}
void BazaarCatalogue::setConnectionState(QString state) {
    if(connection_==state)return;
    connection_=state;
    status_=state=="connected" ? "Player bazaars are not available yet." :
        state=="connecting" ? "Connecting…" : "Sign in to browse player bazaars.";
    emit changed();
}
QJsonObject BazaarCatalogue::navigation() const {
    auto ids=favorites_.values();ids.sort();
    return {{"selection",selection_},{"lastRoom",lastRoom_},{"search",search_},
        {"favoritesOnly",favoritesOnly_},{"favorites",QJsonArray::fromStringList(ids)},
        {"scroll",scroll_}};
}
void BazaarCatalogue::restore(const QJsonObject& state) {
    dialog_.clear();realmIndex_=0;
    search_=state["search"].toString().left(64);
    favoritesOnly_=state["favoritesOnly"].toBool();favorites_.clear();
    for(const auto& id:state["favorites"].toArray())
        if(id.isString()&&!id.toString().isEmpty()&&id.toString().size()<=256&&favorites_.size()<100)favorites_.insert(id.toString());
    lastRoom_=state["lastRoom"].toString();
    const auto selected=state["selection"].toString("official");
    selection_=QStringList{"official","search","filter","create"}.contains(selected)||selected.startsWith("room:")?selected:"official";
    setScroll(state["scroll"].toDouble());
    // Keep an ID while awaiting a directory, but never restore a join/dialog.
    rebuild();
}
void BazaarCatalogue::setPresentation(QVariantList rooms,QVariantList realms,QString status) {
    fixture_=true;
    const auto previous=selection_;
    all_.clear();QSet<QString> ids;
    for(const auto& value:rooms) {
        auto row=value.toMap();const auto id=row.value("id").toString();
        if(id.isEmpty()||ids.contains(id))continue;
        ids.insert(id);all_.append(row);
    }
    realms_=realms;status_=status;
    realmIndex_=qBound(0,realmIndex_,qMax(0,int(realms_.size())-1));
    rebuild();
    if(previous.startsWith("room:")&&selectedIndex()<0)focus("official");
}
void BazaarCatalogue::rebuild() {
    visible_.clear();
    for(const auto& value:all_) {
        auto row=value.toMap();const auto id=row.value("id").toString();
        const bool favorite=favorites_.contains(id);
        if(favoritesOnly_&&!favorite)continue;
        if(!search_.isEmpty()&&!(row.value("title").toString()+" "+row.value("ownerName").toString()).contains(search_,Qt::CaseInsensitive))continue;
        row["favorite"]=favorite;visible_.append(row);
    }
    emit rowsChanged();emit changed();
}
void BazaarCatalogue::focus(QString id) {
    if(!dialog_.isEmpty())return;
    const bool control=QStringList{"official","search","filter","create"}.contains(id);
    bool room=false;
    for(const auto& value:visible_)if(id=="room:"+value.toMap().value("id").toString())room=true;
    if(!control&&!room)return;
    if(room)lastRoom_=id;
    if(selection_==id)return;
    selection_=id;emit changed();
}
void BazaarCatalogue::focusRoom(int index) {
    if(visible_.isEmpty()){focus("search");return;}
    focus("room:"+visible_[qBound(0,index,int(visible_.size())-1)].toMap().value("id").toString());
}
void BazaarCatalogue::activate(QString id) {
    if(!dialog_.isEmpty())return;
    focus(id);if(selection_!=id)return;
    if(id=="official"){dialog_="realms";realmIndex_=0;emit changed();}
    else if(id=="search")editSearch();
    else if(id=="filter")toggleFilter();
    else if(id=="create"){beginForm(!own_.isEmpty());}
    else if(id.startsWith("room:")){detailId_=id;dialog_="details";dialogIndex_=0;emit changed();}
}
void BazaarCatalogue::editSearch() {
    if(!dialog_.isEmpty())return;
    textField_="search";focus("search");emit textRequested(search_);
}
void BazaarCatalogue::applySearch(QString text) {
    search_=text.trimmed().left(64);setScroll(0);selection_="search";rebuild();if(backend_&&!fixture_)refresh();
}
void BazaarCatalogue::toggleFilter() {
    if(!dialog_.isEmpty())return;
    favoritesOnly_=!favoritesOnly_;setScroll(0);selection_="filter";rebuild();if(backend_&&!fixture_)refresh();
}
void BazaarCatalogue::toggleFavorite(QString id) {
    if(!dialog_.isEmpty())return;
    bool found=false;for(const auto& v:visible_)if(v.toMap().value("id")==id)found=true;
    if(!found)return;
    const int index=selectedIndex();
    if(favorites_.contains(id))favorites_.remove(id);else if(favorites_.size()<100)favorites_.insert(id);
    rebuild();
    if(selection_.startsWith("room:")&&selectedIndex()<0)focusRoom(index);
}
void BazaarCatalogue::closeDialog(bool all) {
    ++accessGeneration_;moderating_=false;
    if(!all&&(dialog_=="appearance"||dialog_=="access")){dialog_=formReturn_.isEmpty()?"manage":formReturn_;dialogIndex_=0;message_.clear();emit changed();return;}
    if(!all&&dialog_=="blocks"){dialog_="access";dialogIndex_=0;message_.clear();emit changed();return;}
    if(!all&&dialog_=="moderate"){dialog_="blocks";dialogIndex_=0;loadAccess();return;}
    if(dialog_.isEmpty())return;
    if(dialog_=="review"&&!all) {if(backend_&&!account()["review"].toMap().isEmpty())backend_->cancelPurchaseReview();dialog_="purchase";dialogIndex_=0;}
    else {dialog_.clear();textField_.clear();message_.clear();if(backend_&&!account()["review"].toMap().isEmpty())backend_->cancelPurchaseReview();}
    emit changed();
}
void BazaarCatalogue::chooseRealm(int index) {
    if(dialog_!="realms"||index<0||index>=realms_.size())return;
    realmIndex_=index;emit changed();
    const auto row=realms_[index].toMap();
    if(row.value("capacity").toInt()<=0||row.value("visitors").toInt()>=row.value("capacity").toInt())return;
    // A fixture's occupancy is not admission. Real SDK handoff is a later slice.
    emit notice("This realm is not available to enter yet.");
}
bool BazaarCatalogue::dispatch(Action action) {
    if(!dialog_.isEmpty()) {
        if(dialog_!="realms") {
            if(action==Action::Back)closeDialog();
            else if(action==Action::Up||action==Action::Down){dialogIndex_=qBound(0,dialogIndex_+(action==Action::Down?1:-1),qMax(0,int(dialogRows().size())-1));emit changed();}
            else if(action==Action::Confirm)dialogAction(dialogRows().value(dialogIndex_).toMap()["id"].toString());
            return true;
        }
        if(action==Action::Back)closeDialog();
        else if(dialog_=="realms"&&(action==Action::Up||action==Action::Down)) {
            realmIndex_=qBound(0,realmIndex_+(action==Action::Down?1:-1),qMax(0,int(realms_.size())-1));emit changed();
        } else if(action==Action::Confirm){if(dialog_=="realms"&&!realms_.isEmpty())chooseRealm(realmIndex_);else closeDialog();}
        return true;
    }
    if(action==Action::Back){if(selection_=="official")return false;focus("official");return true;}
    if(action==Action::Confirm){activate(selection_);return true;}
    if(action==Action::ToggleFavorite){editSearch();return true;}
    if(action==Action::LocalAction||action==Action::ContextMenu) {
        openMenu();
        return true;
    }
    const int index=selectedIndex();
    const bool up=action==Action::Up||action==Action::ScrollUp, down=action==Action::Down||action==Action::ScrollDown;
    if(index>=0) {
        if(up){if(index<2)focus("search");else focusRoom(index-2);}
        else if(down){if(index+2<visible_.size())focusRoom(index+2);else if(more())refresh(true);}
        else if(action==Action::Left){if(index%2==0)focus("official");else focusRoom(index-1);}
        else if(action==Action::Right&&index%2==0&&index+1<visible_.size())focusRoom(index+1);
    } else if(selection_=="official") {
        if(action==Action::Right) {
            int remembered=0;for(int i=0;i<visible_.size();++i)if("room:"+visible_[i].toMap().value("id").toString()==lastRoom_)remembered=i;
            focusRoom(remembered);
        } else if(up)focus("search");
    } else {
        const QStringList controls{"search","filter","create"};const int control=controls.indexOf(selection_);
        if(down)focusRoom(0);
        else if(action==Action::Left)focus(control<=0?"official":controls[control-1]);
        else if(action==Action::Right)focus(controls[qMin(2,control+1)]);
    }
    return true;
}
}
