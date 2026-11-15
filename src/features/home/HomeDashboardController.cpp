#include "HomeDashboardController.h"
#include "HomeWidgetPackages.h"
#include <QCryptographicHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSet>
#include <QSettings>
#include <algorithm>

namespace trainer {
HomeDashboardController::HomeDashboardController(LibraryRepository& library,AchievementProvider& provider,SocialController& social,QObject* parent)
    :QObject(parent),library_(library),provider_(provider),social_(social) {
    connect(&social_,&SocialController::changed,this,[this,account=social.account()["userId"].toString()]() mutable {
        const auto next=social_.account()["userId"].toString();
        if(next!=account){account=next;focus_="play";}
        emit changed();
    });
    connect(&provider_,&AchievementProvider::snapshotChanged,this,[this,context=provider_.context()]() mutable {
        if(context!=provider_.context()){context=provider_.context();companion_.clearAchievements();}
        achievementsCached_=false;emit changed();
    });
    connect(&provider_,&AchievementProvider::achievementAwardsEarned,&companion_,&HomeCompanion::celebrateAwards);
    // Companion bindings observe their own controller. Care ticks and animation
    // state must not invalidate every dashboard and shell property.
    connect(&companion_,&HomeCompanion::widgetChangeRequested,this,&HomeDashboardController::editWidget);
}
void HomeDashboardController::setContext(QString adventure,bool generic) {
    if(adventure_==adventure && generic_==generic)return;
    companion_.end();adventure_=std::move(adventure);generic_=generic;focus_="play";widgetPicking_=false;achievementsCached_=false;emit changed();
}
QVariantList HomeDashboardController::widgetChoices() const {
    return QVariantList{QVariantMap{{"id",""},{"title","No widget"}},
        QVariantMap{{"id","downloads"},{"title","Downloads"}},
        QVariantMap{{"id","storage"},{"title","Storage"}},
        QVariantMap{{"id","clock"},{"title","Clock"}},
        QVariantMap{{"id","battery"},{"title","Battery"}}} + installedWidgets_;
}
void HomeDashboardController::setInstalledWidgets(const QString& root,const QVariantList& receipts) {
    const auto rows=installedHomeWidgets(root,receipts);
    if(rows==installedWidgets_)return;
    companion_.end();installedWidgets_=rows;
    if(widget().isEmpty())companion_.setActive(false);
    // Keep the saved identity across removal/reinstall, but never render a removed object.
    widgetPicking_=false;widgetChoiceIndex_=0;emit changed();
}
bool HomeDashboardController::selectPackageWidget(const QString& package,const QString& localId) {
    if(ownerKey_.isEmpty())return false;
    for(const auto& value:installedWidgets_){const auto row=value.toMap();
        if(row["package"]==package && (localId.isEmpty() || row["localId"]==localId)){
            applyWidget(row["id"].toString());return true;
        }
    }
    return false;
}
bool HomeDashboardController::allowsStartWidgets(const QString& app) const {
    for(const auto& value:installedWidgets_){const auto row=value.toMap();
        if(row["package"]==app)return row["allowStartWidgets"].toBool();
    }return true;
}
QVariantMap HomeDashboardController::widget() const {
    if(widgetId_.isEmpty())return {};
    for(const auto& value:widgetChoices())if(value.toMap()["id"]==widgetId_) {
        auto row=value.toMap();row["w"]=4;row["h"]=4;return row;
    }
    return {};
}
void HomeDashboardController::setOwner(const QString& owner) {
    companion_.setOwner(owner);
    const auto key=owner.isEmpty()?QString():"home/widget/v1/"+QString::fromLatin1(QCryptographicHash::hash(owner.toUtf8(),QCryptographicHash::Sha256).toHex());
    if(key==ownerKey_)return;
    ownerKey_=key;widgetId_=key.isEmpty()?QString():QSettings().value(key).toString();
    if(widgetId_=="companion")widgetId_="crates:home-companion:pet";
    widgetPicking_=false;widgetChoiceIndex_=0;emit changed();
}
void HomeDashboardController::editWidget() {
    if(ownerKey_.isEmpty())return;
    companion_.end();
    focus_="widget";widgetPicking_=true;widgetChoiceIndex_=0;
    const auto rows=widgetChoices();for(int i=0;i<rows.size();++i)if(rows[i].toMap()["id"]==widgetId_)widgetChoiceIndex_=i;
    emit changed();
}
void HomeDashboardController::chooseWidget(const QString& id) {
    if(!widgetPicking_||ownerKey_.isEmpty())return;
    const auto rows=widgetChoices();bool valid=false;for(const auto& row:rows)if(row.toMap()["id"]==id)valid=true;
    if(!valid)return;
    applyWidget(id);
}
void HomeDashboardController::applyWidget(const QString& id) {
    // Crates/SDK may activate from another page where the shell closes pickers.
    // Publish one completed selection, never an intermediate editWidget state.
    companion_.end();widgetId_=id;QSettings().setValue(ownerKey_,id);
    widgetPicking_=false;focus_="widget";emit changed();
}
void HomeDashboardController::closeWidgetPicker() {if(widgetPicking_){widgetPicking_=false;emit changed();}}
void HomeDashboardController::activateWidget() {
    if(widget()["renderer"]=="avatar-care-v1") {if(companion_.interacting())companion_.perform(companion_.focus());else companion_.begin();}
    else if(widget().isEmpty())editWidget();else emit widgetActivated(widgetId_);
}
QVariantList HomeDashboardController::people() const {
    auto rows=social_.quickPeople();
    for(auto& value:rows){auto row=value.toMap();row["key"]="person:"+row["id"].toString();row["type"]="person";value=row;}
    return rows;
}
QVariantList HomeDashboardController::achievements() const {
    QVariantList rows;const auto context=provider_.context();
    if(context.accountId.isEmpty()){achievementsCached_=false;achievementsCache_.clear();return rows;}
    const auto revision=library_.libraryRevision();
    if(revision && achievementsCached_ && achievementsRevision_==revision && achievementsContext_==context)return achievementsCache_;
    QSet<QString> games;for(const auto& game:library_.adventures())games.insert(game.id);
    for(const auto& set:provider_.sets()) {
        if(!set.supported || !games.contains(set.adventureId) || set.adventureId!=adventure_)continue;
        const auto snapshot=provider_.snapshot(set.id);
        if(snapshot.context!=context || snapshot.setId!=set.id
           || (snapshot.state!=AchievementState::Ready && snapshot.state!=AchievementState::Offline))continue;
        QHash<QString,int> definitions;
        for(int i=0;i<snapshot.definitions.size();++i)
            if(!definitions.contains(snapshot.definitions[i].id))definitions.insert(snapshot.definitions[i].id,i);
        for(const auto& unlock:snapshot.unlocks) {
            if(unlock.unlocked!=true)continue;
            const auto found=definitions.constFind(unlock.achievementId);
            if(found==definitions.cend())continue;
            const auto* definition=&snapshot.definitions[found.value()];
            const auto identity=QJsonDocument(QJsonArray{context.providerId,context.accountId,set.id,definition->id}).toJson(QJsonDocument::Compact);
            const auto key="ra:"+QString::fromLatin1(QCryptographicHash::hash(identity,QCryptographicHash::Sha256).toHex());
            rows.append(QVariantMap{{"key",key},{"type","achievement"},{"id",definition->id},{"set",set.id},
                {"adventure",set.adventureId},{"name",definition->title},{"game",set.title},{"description",definition->description},
                {"icon",definition->badgeName.isEmpty() ? QString() : "https://media.retroachievements.org/Badge/" + definition->badgeName + ".png"},
                {"date",unlock.earnedAt},{"offline",snapshot.state==AchievementState::Offline},
                {"mode",unlock.mode==AchievementMode::Hardcore?"Hardcore":unlock.mode==AchievementMode::Standard?"Standard":"Mode unavailable"}});
        }
    }
    std::stable_sort(rows.begin(),rows.end(),[](const auto& a,const auto& b){return a.toMap()["date"].toDateTime()>b.toMap()["date"].toDateTime();});
    while(rows.size()>16)rows.removeLast();
    achievementsCached_=revision.has_value();achievementsRevision_=revision;achievementsContext_=context;achievementsCache_=rows;
    return rows;
}
QList<QStringList> HomeDashboardController::zones() const {
    QList<QStringList> result;for(const auto& rows:{people(),achievements()}) {
        QStringList keys;for(const auto& row:rows)keys.append(row.toMap()["key"].toString());result.append(keys);
    }result[0].prepend("lobbies");return result;
}
QVariantMap HomeDashboardController::target(const QString& key) const {
    if(key=="ship")return {{"type","ship"},{"key",key}};
    if(key=="lobbies")return {{"type","lobbies"},{"key",key}};
    if(key=="play" || key=="screens" || key=="widget")return {{"type",key},{"key",key}};
    for(const auto& rows:{people(),achievements()})for(const auto& row:rows)if(row.toMap()["key"]==key)return row.toMap();
    return {}; // An expired focused item never becomes a new row at its old index.
}
void HomeDashboardController::select(const QString& key) {if(!target(key).isEmpty()){if(key!="widget")companion_.end();focus_=key;emit changed();}}
void HomeDashboardController::move(Action action) {
    if(widgetPicking_) {
        if(action==Action::Back || action==Action::Home || action==Action::SystemMenu)closeWidgetPicker();
        else if(action==Action::Confirm)chooseWidget(widgetChoices().value(widgetChoiceIndex_).toMap()["id"].toString());
        else if(action==Action::Up || action==Action::Down){widgetChoiceIndex_=std::clamp(widgetChoiceIndex_+(action==Action::Up?-1:1),0,int(widgetChoices().size())-1);emit changed();}
        return;
    }
    if(focus_=="ship") {
        if(action==Action::Down || action==Action::Left)select("lobbies");
        else if(action==Action::Back || action==Action::Right || action==Action::NextFace || action==Action::PreviousFace)reset();
        return;
    }
    if(action==Action::Up && (focus_=="lobbies" || focus_=="screens")){select("ship");return;}
    if(focus_=="widget") {
        if(widget()["renderer"]=="avatar-care-v1"&&companion_.interacting()) {
            if(action==Action::NextFace || action==Action::PreviousFace)reset();
            else companion_.dispatch(action);
            return;
        }
        if(action==Action::Up)select(people().isEmpty()?"lobbies":people().last().toMap()["key"].toString());
        else if(action==Action::Right || action==Action::Back || action==Action::NextFace || action==Action::PreviousFace)reset();
        return;
    }
    if(action==Action::Down && (focus_.startsWith("person:") || (focus_=="lobbies" && people().isEmpty()))){select("widget");return;}
    const auto groups=zones();int zone=-1,index=-1;
    if(focus_=="lobbies"&&action==Action::Down&&!people().isEmpty()){select(people().first().toMap()["key"].toString());return;}
    if(focus_.startsWith("person:")&&action==Action::Up){select("lobbies");return;}
    for(int i=0;i<groups.size();++i)if(groups[i].contains(focus_)){zone=i;index=groups[i].indexOf(focus_);break;}
    if(action==Action::PreviousFace || action==Action::NextFace) {
        // Two visible blocks: people/lobby, and the current game.
        if(focus_=="lobbies" || focus_.startsWith("person:"))reset();
        else select("lobbies");
        return;
    }
    if(action==Action::Back){reset();return;}
    if(generic_) {
        if(focus_=="play") {
            if(action==Action::Up){select("screens");return;}
            if(action==Action::Left){for(int i:{1,0})if(!groups[i].isEmpty()){select(groups[i].last());return;}return;}
            return;
        }
        if(focus_=="screens") {
            if(action==Action::Down){reset();return;}
            if(action==Action::Left){for(int i:{0})if(!groups[i].isEmpty()){select(groups[i].first());return;}return;}
            return;
        }
        if(zone==1 && action==Action::Up){select("screens");return;}
        if(zone==1 && action==Action::Left && index==0){for(int i:{0})if(!groups[i].isEmpty()){select(groups[i].last());return;}return;}
        if(zone==1 && action==Action::Down)return;
        if((zone==0 && index==groups[0].size()-1) && action==Action::Right){select(zone==0?"screens":groups[1].isEmpty()?"play":groups[1].first());return;}
    }
    if(!generic_ && focus_=="play" && action==Action::Left){select("screens");return;}
    if(!generic_ && focus_=="screens" && action==Action::Right){select("play");return;}
    if(!generic_ && focus_=="screens" && action==Action::Left){select(groups[1].isEmpty()?"widget":groups[1].last());return;}
    if(!generic_ && zone==1 && action==Action::Left && index==0){select("widget");return;}
    if(!generic_ && zone==1 && action==Action::Right && index==groups[1].size()-1){select("screens");return;}
    if(zone<0) {
        if(focus_.startsWith("person:") && (action==Action::Left || action==Action::Right) && !people().isEmpty()) {
            select(people().first().toMap()["key"].toString());return;
        }
        if(action==Action::Left || action==Action::Up || action==Action::Down)for(const auto& group:groups)if(!group.isEmpty()){select(group.first());return;}
        return;
    }
    if(action==Action::Right && index==groups[zone].size()-1) {reset();return;}
    if(action==Action::Left || action==Action::Right) {
        select(groups[zone][std::clamp(index+(action==Action::Right?1:-1),0,int(groups[zone].size())-1)]);return;
    }
    if(action==Action::Up || action==Action::Down) {
        const int delta=action==Action::Down?1:-1;
        for(int next=zone+delta;next>=0 && next<groups.size();next+=delta)if(!groups[next].isEmpty()){select(delta>0?groups[next].first():groups[next].last());return;}
    }
}
}
