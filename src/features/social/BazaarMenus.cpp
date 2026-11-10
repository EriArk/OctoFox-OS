#include "BazaarCatalogue.h"
#include "features/accounts/BackendAccount.h"
#include <QJsonArray>
#include <QUuid>

namespace trainer {
void BazaarCatalogue::setBackend(BackendAccount* backend) {
    if(backend_==backend)return;
    if(backend_)disconnect(backend_,nullptr,this,nullptr);
    backend_=backend;
    if(backend_)connect(backend_,&BackendAccount::changed,this,&BazaarCatalogue::syncBackend);
    syncBackend();
}
QVariantMap BazaarCatalogue::account() const {return backend_?backend_->bazaarAccount():QVariantMap{};}
bool BazaarCatalogue::busy() const {return loading_||saving_||moderating_||account()["busy"].toBool();}
void BazaarCatalogue::syncBackend() {
    const auto state=account();const auto player=state["playerId"].toString();const bool connected=state["connected"].toBool();
    const bool identityChanged=player!=backendPlayer_, connectionChanged=connected!=connected_;
    if(identityChanged||connectionChanged) {
        ++accessGeneration_;moderating_=false;blocks_.clear();accessTarget_={};accessNext_.clear();
        ++generation_;loading_=saving_=false;next_.clear();all_.clear();
        if(identityChanged){draft_={};dialog_.clear();message_.clear();textField_.clear();formReturn_.clear();own_={};
            if(!backendPlayer_.isEmpty()){favorites_.clear();search_.clear();selection_="official";setScroll(0);}}
        backendPlayer_=player;connected_=connected;rebuild();
    }
    const bool newlyOwned=own_.isEmpty()&&!state["owned"].toMap().isEmpty();
    own_=QJsonObject::fromVariantMap(state["owned"].toMap());
    if(newlyOwned&&(dialog_=="create"||dialog_=="review")) {dialog_="manage";draft_=own_;dialogIndex_=0;message_="Your bazaar is created. World entry is being prepared.";if(active_&&!saving_)refresh();}
    if(state["licensed"].toBool()&&own_.isEmpty()&&(dialog_=="purchase"||dialog_=="review")) {dialog_="ready";dialogIndex_=0;message_="Purchased. Create your bazaar whenever you are ready.";}
    if(reloadDraft_&&!state["busy"].toBool()&&!state["stale"].toBool()) {
        reloadDraft_=false;if(dialog_=="manage")draft_=own_;message_="Saved settings reloaded.";
    }
    if(!connected_)status_="Sign in to TrainerOS to browse player bazaars.";
    if(active_&&(identityChanged||connectionChanged)&&connected_&&!fixture_)refresh();
    emit changed();
}
void BazaarCatalogue::setActive(bool value) {
    if(active_==value)return;
    active_=value;
    if(value&&backend_&&!fixture_){if(all_.isEmpty())refresh();backend_->refreshShop();}
    emit changed();
}
void BazaarCatalogue::refresh(bool append) {
    if(!backend_||fixture_||saving_||(append&&(loading_||next_.isEmpty())))return;
    if(!connected_){status_="Sign in to TrainerOS to browse player bazaars.";emit changed();return;}
    const auto generation=++generation_;loading_=true;
    if(!append)next_.clear();
    status_="Refreshing bazaars…";emit changed();
    QJsonObject args{{"q",search_}};if(append)args["after"]=next_;
    if(favoritesOnly_)args["favorites"]=QJsonArray::fromStringList(favorites_.values());
    backend_->bazaarRequest("directory",args,[this,generation,append](int status,QJsonObject result){
        if(generation!=generation_)return;
        loading_=false;
        if(status!=200||result["player_id"]!=backendPlayer_||!result["items"].isArray()||result["items"].toArray().size()>24) {
            status_="Could not refresh bazaars. Open the menu to retry.";emit changed();return;
        }
        QVariantList rows;QSet<QString> ids;
        for(const auto value:result["items"].toArray()) {
            const auto row=value.toObject();const auto id=row["id"].toString();
            if(id.size()!=36||QUuid(id).isNull()||ids.contains(id)||row["name"].toString().isEmpty()||row["name"].toString().size()>48
                ||row["description"].toString().size()>280||!row["listed"].isBool()||!row["owned"].isBool()
                ||!QStringList{"open","closed"}.contains(row["access"].toString())||row["join_available"]!=false
                ||!QStringList{"market","grove","harbor"}.contains(row["cover"].toString("market"))
                ||!QStringList{"shop","community","companion","trophy","guide"}.contains(row["badge"].toString("shop"))) {
                status_="Could not read the bazaar catalogue. Retry later.";emit changed();return;
            }
            ids.insert(id);auto entry=row.toVariantMap();entry["title"]=row["name"].toString();entry["ownerName"]=row["owner_name"].toString();
            entry["cover"]=QString("qrc:/bazaar/%1.png").arg(row["cover"].toString("market")=="market"?"official":row["cover"].toString());entry["visitors"]=QVariant();rows.append(entry);
        }
        const auto next=result["next"].toString();if(!next.isEmpty()&&(next.size()!=36||QUuid(next).isNull())){status_="Invalid catalogue cursor.";emit changed();return;}
        if(!append)all_.clear();
        QSet<QString> existing;for(const auto& row:all_)existing.insert(row.toMap()["id"].toString());
        for(const auto& row:rows)if(!existing.contains(row.toMap()["id"].toString()))all_.append(row);
        next_=all_.size()<1000?next:QString();status_=all_.isEmpty()?"No player bazaars here yet.":"";
        rebuild();if(selection_.startsWith("room:")&&selectedIndex()<0)focus("official");
    });
}
QJsonObject BazaarCatalogue::formDetails() const {return {{"name",draft_["name"]},{"description",draft_["description"]},{"listed",draft_["listed"]},{"access",draft_["access"]},{"cover",draft_["cover"].toString("market")},{"badge",draft_["badge"].toString("shop")}};}
void BazaarCatalogue::beginForm(bool editing) {
    dialog_=editing?"manage":account()["licensed"].toBool()?"ready":"purchase";dialogIndex_=0;message_.clear();
    draft_=editing?own_:QJsonObject{{"name",""},{"description",""},{"listed",true},{"access","open"}};
    if(backend_&&connected_)backend_->refreshShop();
    emit changed();
}
QString BazaarCatalogue::editorTitle() const {return textField_=="name"?"Bazaar name":textField_=="description"?"Bazaar description":"Search player bazaars";}
int BazaarCatalogue::editorLimit() const {return textField_=="name"?48:textField_=="description"?280:64;}
void BazaarCatalogue::applyText(QString text) {
    if(textField_=="name"||textField_=="description"){draft_[textField_]=text.trimmed().left(editorLimit());textField_.clear();emit changed();}
    else {textField_.clear();applySearch(text);}
}
void BazaarCatalogue::openMenu() {if(!dialog_.isEmpty())return;detailId_=selection_;dialog_="menu";dialogIndex_=0;message_.clear();emit changed();}
QString BazaarCatalogue::summary() const {
    if(dialog_=="purchase"||dialog_=="review")return "Unlock one personal bazaar permanently. Create it later, whenever you are ready.";
    if(dialog_=="ready")return "Your right to a personal bazaar is already purchased. Creation costs no extra Sparks.";
    if(dialog_=="create")return "Already purchased. Choose your settings and create your bazaar for free.";
    if(dialog_=="appearance")return "Preview your card. Changes are applied when you save the bazaar settings.";
    if(dialog_=="access")return "Catalogue visibility and visitor access are separate. Save settings to apply changes.";
    if(dialog_=="blocks")return "Blocked players cannot enter your bazaar when worlds open. Choose a player through their existing profile.";
    if(dialog_=="moderate")return accessTarget_["name"].toString()+" — "+(accessTarget_["blocked"].toBool()?"blocked from your bazaar.":"not blocked from your bazaar.");
    if(dialog_=="manage")return "Change the name, description and visitor settings. Changes are free.";
    if(dialog_=="details")for(const auto& value:all_) {const auto row=value.toMap();if("room:"+row["id"].toString()==detailId_)return row["title"].toString()+" · "+row["ownerName"].toString()+". "+row["description"].toString()+" World entry is being prepared.";}
    return {};
}
QVariantList BazaarCatalogue::dialogRows() const {
    QVariantList rows;const auto state=account();
    const auto add=[&](QString id,QString label,QString value={},bool enabled=true){rows.append(QVariantMap{{"id",id},{"label",label},{"value",value},{"enabled",enabled}});};
    if(dialog_=="appearance") {
        add("cover","Cover",draft_["cover"].toString("market"));add("badge","Badge",draft_["badge"].toString("shop"));add("back","Back to settings");
    } else if(dialog_=="access") {
        add("listed","Catalogue",draft_["listed"].toBool()?"Listed":"Hidden");
        add("access","Visitors",draft_["access"]=="open"?"Allowed when the world opens":"Closed");
        if(!own_.isEmpty())add("blocks","Blocked players",{},!busy());
        add("back","Back to settings");
    } else if(dialog_=="blocks") {
        for(const auto& value:blocks_){const auto row=value.toMap();add("player:"+row["player_id"].toString(),row["name"].toString(),"Blocked",!busy());}
        if(!accessNext_.isEmpty())add("blocks-more","Load more",{},!busy());
        add("blocks-refresh","Refresh list",{},!busy());add("back","Back");
    } else if(dialog_=="moderate") {
        if(accessTarget_["blocked"].isBool()&&!accessTarget_["name"].toString().isEmpty())add("block",accessTarget_["blocked"].toBool()?"Allow access again":"Block from my bazaar",{},!busy()&&connected_);
        add("target-refresh","Refresh",{},!busy());add("back","Back");
    } else if(dialog_=="ready") {
        add("setup","Create bazaar", "Already purchased",state["connected"].toBool()&&!busy());add("back","Later");
    } else if(dialog_=="purchase"||dialog_=="create"||dialog_=="manage") {
        if(dialog_!="purchase") {
        add("name","Name",draft_["name"].toString().isEmpty()?"Choose a name":draft_["name"].toString());
        add("description","Description",draft_["description"].toString().isEmpty()?"Add a short description":draft_["description"].toString());
        add("appearance","Card appearance","Preview & edit");
        add("access-settings","Access & players",draft_["access"]=="open"?"Visitors allowed":"Closed");
        }
        if(!state["connected"].toBool())add("sign-in","Sign in to TrainerOS");
        else if(state["pending"].toBool())add("resolve",state["bazaarPending"].toBool()?"Resolve pending purchase":"Resolve the purchase in your profile",{},state["bazaarPending"].toBool()&&!busy());
        else if(state["stale"].toBool())add("reload","Refresh account",{},!busy());
        else if(dialog_=="manage")add("save","Save changes","Free",!busy()&&!draft_["name"].toString().isEmpty());
        else if(dialog_=="create")add("create","Create bazaar","Already purchased",!busy()&&state["licensed"].toBool()&&!draft_["name"].toString().isEmpty());
        else {const auto offer=state["offer"].toMap();add("review","Buy personal bazaar",offer.isEmpty()?"Unavailable":QString::number(offer["price"].toInt())+" Sparks",!busy()&&!offer.isEmpty());}
        if(dialog_=="manage")add("reload","Reload saved settings",{},!busy());
    } else if(dialog_=="review") {
        const auto review=state["review"].toMap();add("buy","Buy personal bazaar",QString::number(review["price"].toInt())+" Sparks",!busy()&&!review.isEmpty());add("back","Back");
    } else if(dialog_=="menu") {
        if(detailId_.startsWith("room:")){add("details","Bazaar details");add("favorite","Save / remove favorite");}
        add("mine",own_.isEmpty()?(state["licensed"].toBool()?"Create a bazaar":"Buy personal bazaar"):"My bazaar");add("refresh","Refresh catalogue",{},!busy());
        if(more())add("more","Load more bazaars",{},!busy());
    } else if(dialog_=="details") {add("favorite","Save / remove favorite");if(detailId_=="room:"+own_["id"].toString())add("mine","Manage my bazaar");add("back","Back");}
    return rows;
}
void BazaarCatalogue::dialogAction(QString action) {
    bool permitted=false;for(const auto& row:dialogRows())if(row.toMap()["id"]==action&&row.toMap()["enabled"].toBool())permitted=true;
    if(!permitted||saving_)return;
    if(action=="appearance"||action=="access-settings"){formReturn_=dialog_;dialog_=action=="appearance"?"appearance":"access";dialogIndex_=0;message_.clear();emit changed();return;}
    if(action=="cover"||action=="badge") {
        const QStringList choices=action=="cover"?QStringList{"market","grove","harbor"}:QStringList{"shop","community","companion","trophy","guide"};
        const auto current=draft_[action].toString(choices.first());draft_[action]=choices[(choices.indexOf(current)+1)%choices.size()];emit changed();return;
    }
    if(action=="blocks"||action=="blocks-refresh"||action=="blocks-more"){dialog_="blocks";dialogIndex_=0;loadAccess({},action=="blocks-more");return;}
    if(action.startsWith("player:")){managePlayer(action.mid(7));return;}
    if(action=="target-refresh"){loadAccess(accessTarget_["player_id"].toString());return;}
    if(action=="block") {
        const auto target=accessTarget_["player_id"].toString(),revision=own_["revision"].toString();const auto generation=++accessGeneration_;
        moderating_=true;message_="Saving access rule…";emit changed();
        backend_->bazaarRequest("block",{{"id",own_["id"]},{"target",target},{"revision",revision},{"blocked",!accessTarget_["blocked"].toBool()}},[this,generation,revision,target](int status,QJsonObject result){
            if(generation!=accessGeneration_)return;
            moderating_=false;
            if(status==200){if(draft_["revision"].toString()==revision)draft_["revision"]=result["bazaar"].toObject()["revision"];message_="Access rule saved.";loadAccess(target);}
            else {message_=status==409?"Access changed. Refresh before trying again.":"Could not save access. Refresh and try again.";emit changed();}
        });return;
    }
    if(action=="setup"){dialog_="create";dialogIndex_=0;message_.clear();emit changed();return;}
    if(action=="back"){closeDialog();return;}
    if(action=="name"||action=="description"){textField_=action;emit textRequested(draft_[action].toString());return;}
    if(action=="listed")draft_["listed"]=!draft_["listed"].toBool();
    else if(action=="access")draft_["access"]=draft_["access"]=="open"?"closed":"open";
    else if(action=="sign-in"){if(backend_)backend_->activate();}
    else if(action=="mine"){beginForm(!own_.isEmpty());return;}
    else if(action=="details")dialog_="details";
    else if(action=="favorite"){const auto old=dialog_;dialog_.clear();toggleFavorite(detailId_.mid(5));dialog_=old;}
    else if(action=="refresh"||action=="more"){dialog_.clear();refresh(action=="more");}
    else if(action=="reload"){if(backend_){reloadDraft_=true;backend_->refreshShop();}}
    else if(action=="resolve"){if(backend_)backend_->resolveBazaarPurchase();}
    else if(action=="review") {backend_->reviewBazaarPurchase();if(!account()["review"].toMap().isEmpty()){dialog_="review";dialogIndex_=0;message_="World entry is not available yet. Create later, with no second payment.";}}
    else if(action=="buy") {backend_->confirmPurchase();if(dialog_=="review"&&account()["review"].toMap().isEmpty()){dialog_="purchase";dialogIndex_=0;}}
    else if(action=="save"||action=="create") {
        auto args=formDetails();if(action=="save"){args["id"]=draft_["id"];args["revision"]=draft_["revision"];}
        const auto generation=generation_;saving_=true;message_="Saving…";
        backend_->bazaarRequest(action=="create"?"create":"update",args,[this,generation](int status,QJsonObject result){
            if(generation!=generation_)return;
            saving_=false;
            if(status==200){draft_=result["bazaar"].toObject();message_="Settings saved.";refresh();}
            else message_=status==409?"Changed on another device. Your draft is kept; reload saved settings before retrying.":"Could not save. Your draft is kept; retry when connected.";
            emit changed();
        });
    }
    emit changed();
}
QVariantMap BazaarCatalogue::cardPreview() const {
    const auto cover=draft_["cover"].toString("market");
    return {{"title",draft_["name"].toString().isEmpty()?"Your bazaar":draft_["name"].toString()},
        {"ownerName","You"},{"description",draft_["description"].toString()},{"access",draft_["access"].toString()},
        {"cover",QString("qrc:/bazaar/%1.png").arg(cover=="market"?"official":cover)},
        {"badge",draft_["badge"].toString("shop")},{"visitors",QVariant()}};
}
void BazaarCatalogue::managePlayer(QString player) {
    if(own_.isEmpty()||QUuid(player).isNull()||player==backendPlayer_||busy())return;
    if(dialog_!="blocks"&&dialog_!="access"){draft_=own_;formReturn_="manage";}
    dialog_="moderate";dialogIndex_=0;accessTarget_={{"player_id",player}};loadAccess(player);
}
void BazaarCatalogue::loadAccess(QString target,bool append) {
    if(!backend_||own_.isEmpty()||moderating_)return;
    const auto generation=++accessGeneration_;moderating_=true;message_="Loading access rules…";emit changed();
    QJsonObject args{{"id",own_["id"]}};if(!target.isEmpty())args["target"]=target;if(append&&!accessNext_.isEmpty())args["after"]=accessNext_;
    backend_->bazaarRequest("access",args,[this,generation,append,target](int status,QJsonObject result){
        if(generation!=accessGeneration_)return;
            moderating_=false;
        const auto rows=result["blocks"].toArray();
        if(status!=200||!result["blocks"].isArray()||rows.size()>100){message_="Could not load access rules. Refresh to retry.";emit changed();return;}
        QVariantList valid;
        for(const auto value:rows){auto row=value.toObject();if(QUuid(row["player_id"].toString()).isNull()||!row["name"].isString()||row["name"].toString().size()>64){message_="Invalid access list.";emit changed();return;}valid.append(row.toVariantMap());}
        const auto next=result["next"].toString();if(!next.isEmpty()&&QUuid(next).isNull()){message_="Invalid access cursor.";emit changed();return;}
        if(!target.isEmpty()) {
            const auto selected=result["target"].toObject();
            if(selected["player_id"]!=target||!selected["blocked"].isBool()||!selected["name"].isString()){message_="Player access unavailable.";emit changed();return;}
            accessTarget_=selected;
        }
        if(!append)blocks_.clear();
        QSet<QString> known;for(const auto& value:blocks_)known.insert(value.toMap()["player_id"].toString());
        for(const auto& value:valid)if(!known.contains(value.toMap()["player_id"].toString()))blocks_.append(value);
        accessNext_=next;message_=target.isEmpty()&&blocks_.isEmpty()?"No blocked players. Manage access from a player's profile.":"";emit changed();
    });
}

}
