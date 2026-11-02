#include "HomeCompanion.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <algorithm>
#include <cmath>

namespace trainer {
namespace { qint64 now(){return QDateTime::currentMSecsSinceEpoch();}
double need(const QJsonObject& o,const char* name){const double v=o.value(name).toDouble(80);return std::isfinite(v)?std::clamp(v,25.,100.):80.;}
const QStringList scenes{"cozy-room","sunny-garden","evening-nook"};
const QStringList foods{"apple","banana","cookie-chocolate","burger","cup-tea","cupcake"}; }
HomeCompanion::HomeCompanion(QObject* parent):QObject(parent){
    timer_.setInterval(1000);connect(&timer_,&QTimer::timeout,this,&HomeCompanion::tick);
}
HomeCompanion::~HomeCompanion(){save();}
void HomeCompanion::setOwner(const QString& owner){
    const auto key=owner.isEmpty()?QString():"home/companion/v1/"+QString::fromLatin1(QCryptographicHash::hash(owner.toUtf8(),QCryptographicHash::Sha256).toHex());
    if(key_==key)return;
    const bool resume=active_;save();timer_.stop();active_=interacting_=menuOpen_=false;key_=key;
    food_=mood_=energy_=80;stamp_=now();quiet_=resting_=false;scene_=scenes[0];focus_=foodIndex_=0;
    activity_.clear();bubble_.clear();bubbleKind_.clear();pendingGame_.clear();pendingAchievements_=0;
    unreadIds_.clear();pendingUnread_=false;actionUntil_=bubbleUntil_=lastHint_=0;
    if(!key_.isEmpty()){
        const auto o=QJsonDocument::fromJson(QSettings().value(key_).toByteArray()).object();
        if(o["schema"]==1){
            food_=need(o,"food");mood_=need(o,"mood");energy_=need(o,"energy");
            quiet_=o["quiet"].toBool();resting_=o["resting"].toBool();
            if(scenes.contains(o["scene"].toString()))scene_=o["scene"].toString();
            stamp_=qMax(qint64(0),qint64(o["stamp"].toDouble(double(stamp_))));
        }
        advanceTo(now());save();
    }
    if(resume&&!key_.isEmpty()){active_=true;timer_.start();}
    emit changed();
}
void HomeCompanion::advanceTo(qint64 utcMs){
    if(key_.isEmpty())return;
    // Re-anchor a backward clock without inventing negative care or freezing for days.
    const double hours=std::clamp(double(utcMs-stamp_)/3600000.,0.,8.);
    food_=std::max(25.,food_-hours*2.);mood_=std::max(25.,mood_-hours*1.5);
    energy_=resting_?std::min(100.,energy_+hours*24.):std::max(25.,energy_-hours*2.);
    if(energy_>=100)resting_=false;
    stamp_=utcMs;
}
void HomeCompanion::save(){
    if(key_.isEmpty())return;
    const QJsonObject o{{"schema",1},{"food",food_},{"mood",mood_},{"energy",energy_},{"stamp",double(stamp_)},
                        {"quiet",quiet_},{"resting",resting_},{"scene",scene_}};
    QSettings s;s.setValue(key_,QJsonDocument(o).toJson(QJsonDocument::Compact));s.sync();lastSave_=now();
}
void HomeCompanion::addGameplaySeconds(qint64 seconds){
    if(key_.isEmpty()||seconds<=0)return;
    advanceTo(now());
    mood_=std::min(100.,mood_+std::min(seconds,qint64(3600))/36.);
    if(now()-lastSave_>=60000)save();
    if(active_)emit changed();
}
void HomeCompanion::setActive(bool value){
    value=value&&!key_.isEmpty();if(value==active_)return;
    advanceTo(now());active_=value;
    if(active_){timer_.start();presentPending();}
    else {timer_.stop();interacting_=menuOpen_=false;activity_.clear();actionUntil_=0;bubble_.clear();bubbleKind_.clear();}
    save();emit changed();
}
QVariantMap HomeCompanion::needs() const {return {{"food",qRound(food_)},{"mood",qRound(mood_)},{"energy",qRound(energy_)}};}
QString HomeCompanion::background() const{return scene_;}
QString HomeCompanion::activity() const{return activity_.isEmpty()?(resting_?"rest":"idle"):activity_;}
QString HomeCompanion::expression() const{
    if(activity_=="celebrate")return "laughing";
    if(activity_=="feed")return "happy";
    if(resting_)return "content";
    if(energy_<45)return "tired";
    if(food_<40||mood_<40)return "sad";
    return "happy";
}
QString HomeCompanion::prop() const{return activity_=="feed"?"food-kit/"+foods[foodIndex_]+".glb":resting_?"furniture-kit/loungeChair.glb":"";}
void HomeCompanion::begin(){if(!active_)return;if(!interacting_)focus_=0;interacting_=true;emit changed();}
void HomeCompanion::end(){if(!interacting_)return;interacting_=menuOpen_=false;emit changed();}
void HomeCompanion::toggleMenu(){if(!active_)return;interacting_=true;menuOpen_=!menuOpen_;focus_=menuOpen_?3:6;emit changed();}
void HomeCompanion::perform(int index){
    if(!active_||index<0||index>7||index==1)return;
    if(index==6){toggleMenu();return;}
    if(index==7){end();emit widgetChangeRequested();return;}
    interacting_=true;focus_=index;
    if(index==5){openHint();return;}
    if(index==3){scene_=scenes[(scenes.indexOf(scene_)+1)%scenes.size()];save();emit changed();return;}
    if(index==4){quiet_=!quiet_;if(quiet_){bubble_.clear();bubbleKind_.clear();pendingAchievements_=0;pendingUnread_=false;}save();emit changed();return;}
    // A repeated held/tapped action cannot stack rewards or replace its own animation.
    if(!activity_.isEmpty()&&now()<actionUntil_)return;
    advanceTo(now());bubble_.clear();bubbleKind_.clear();const bool wasResting=resting_;resting_=false;
    if(index==0){food_=std::min(100.,food_+24);foodIndex_=(foodIndex_+1)%foods.size();activity_="feed";}
    if(index==2){resting_=!wasResting&&energy_<100;activity_.clear();}
    actionUntil_=now()+4500;save();emit changed();
}
void HomeCompanion::dispatch(Action a){
    if(!interacting_)return;
    if(a==Action::Back){if(menuOpen_)toggleMenu();else end();return;}
    if(a==Action::Confirm){perform(focus_);return;}
    if(menuOpen_){
        const QList<int> items{3,4,5,7};int current=items.indexOf(focus_);
        if(a==Action::Up)current=std::max(0,current-1);
        if(a==Action::Down)current=std::min(3,current+1);
        focus_=items.value(current,3);
    }else{
        if(a==Action::Left)focus_=focus_==6?2:0;
        if(a==Action::Right)focus_=focus_==0?2:6;
        if(a==Action::Up)focus_=6;
        if(a==Action::Down&&focus_==6)focus_=0;
    }
    emit changed();
}
void HomeCompanion::celebrate(const QString& game,const QStringList& titles){
    if(key_.isEmpty()||quiet_||titles.isEmpty())return;
    pendingAchievements_=std::min(99,pendingAchievements_+int(titles.size()));pendingGame_=game.left(80);
    if(active_)presentPending();emit changed();
}
void HomeCompanion::setNotifications(const QVariantList& rows){
    QSet<QString> ids;for(const auto& v:rows){const auto r=v.toMap();if(r["unread"].toBool()&&!r["id"].toString().isEmpty())ids.insert(r["id"].toString());}
    if(ids==unreadIds_)return;
    auto added=ids;added.subtract(unreadIds_);unreadIds_=ids;
    if(!added.isEmpty())pendingUnread_=true;
    if(ids.isEmpty()){pendingUnread_=false;if(bubbleKind_=="notifications"){bubble_.clear();bubbleKind_.clear();}}
    if(active_)presentPending();emit changed();
}
void HomeCompanion::presentPending(){
    if(!active_||quiet_||!activity_.isEmpty()||!bubble_.isEmpty())return;
    if(pendingAchievements_){
        bubble_=pendingAchievements_==1?"Achievement unlocked!":"%1 achievements unlocked!";
        if(pendingAchievements_>1)bubble_=bubble_.arg(pendingAchievements_);
        bubbleKind_="achievement";pendingAchievements_=0;activity_="celebrate";actionUntil_=now()+3500;bubbleUntil_=now()+10000;
    }else if(pendingUnread_&&!unreadIds_.isEmpty()&&(!lastHint_||now()-lastHint_>=600000)){
        bubble_="You have unread notifications";bubbleKind_="notifications";pendingUnread_=false;lastHint_=now();bubbleUntil_=now()+8000;
    }
}
void HomeCompanion::openHint(){if(!active_)return;bubble_.clear();bubbleKind_.clear();pendingUnread_=false;emit inboxRequested();emit changed();}
void HomeCompanion::tick(){
    advanceTo(now());
    if(!activity_.isEmpty()&&now()>=actionUntil_)activity_.clear();
    if(!bubble_.isEmpty()&&now()>=bubbleUntil_){bubble_.clear();bubbleKind_.clear();}
    presentPending();if(now()-lastSave_>=60000)save();emit changed();
}
}
