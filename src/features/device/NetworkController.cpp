#include "NetworkController.h"
#include <QJsonArray>
#include <algorithm>
#include <QRegularExpression>
namespace trainer {
NetworkController::NetworkController(QObject* parent):QObject(parent){
    poll_.setInterval(8000);
    connect(&poll_,&QTimer::timeout,this,[this]{if(active_&&!busy_&&!detailsOpen()&&!failed_&&prompt_.isEmpty()&&textMode_.isEmpty())run("list");});
}
void NetworkController::configure(NetworkService* service){
    if(service_)disconnect(service_,nullptr,this,nullptr);
    service_=service;
    connect(service_,&NetworkService::event,this,&NetworkController::receive);
    connect(service_,&NetworkService::finished,this,[this](const QString& error){
        busy_=false;prompt_.clear();confirmation_.clear();textMode_.clear();pending_={};
        emit closeKeyboardRequested();
        if(operation_!="list" || !error.isEmpty()) {status_=error;failed_=!error.isEmpty() && error!="Cancelled";}
        if(active_ && pendingFace_<0 && !bluetooth_ && operation_=="connect" && failed_) {detail_=target_;detailFocus_=0;}
        if(!failed_ && operation_=="forget")detail_.clear();
        if(pendingFace_>=0&&active_){const bool target=pendingFace_==1;pendingFace_=-1;openFace(target);return;}
        emit changed();
    });
}
void NetworkController::setActive(bool active){
    if(active_==active)return;
    active_=active;
    if(active){poll_.start();if(!busy_)run("list");}
    else {poll_.stop();leave();}
}
void NetworkController::leave(){
    pendingFace_=-1;detail_.clear();target_.clear();failed_=false;status_.clear();
    if(busy_&&service_)service_->cancel();
    textMode_.clear();pending_={};prompt_.clear();confirmation_.clear();emit closeKeyboardRequested();emit changed();
}
void NetworkController::openFace(bool bluetooth){
    detail_.clear();target_.clear();failed_=false;status_.clear();
    if(bluetooth_!=bluetooth){bluetooth_=bluetooth;rows_.clear();focus_=0;}
    textMode_.clear();pending_={};prompt_.clear();confirmation_.clear();
    emit closeKeyboardRequested();
    // A prior scan/pair may still be cancelling after its popup was closed.
    // Wait for that request to finish before starting the requested face.
    if(busy_){pendingFace_=bluetooth?1:0;setActive(true);if(service_)service_->cancel();emit changed();return;}
    pendingFace_=-1;
    if(active_)run("list");else setActive(true);
}
void NetworkController::run(const QString& op,const QJsonObject& extra){
    if(busy_)return;
    if(!service_){status_="Connections are available on your handheld.";emit changed();return;}
    auto request=extra;request["op"]=op;request["kind"]=bluetooth_?"bluetooth":"wifi";
    operation_=op;
    busy_=true;if(op!="list"){failed_=false;status_=op=="scan"?"Looking nearby…":op=="pair"?"Pairing…":op=="disconnect"?"Disconnecting…":op=="forget"?"Forgetting…":op=="autojoin"?"Saving preference…":"Connecting…";
    }
    emit changed();service_->request(request);
}
void NetworkController::receive(const QJsonObject& value){
    if(!active_||pendingFace_>=0){if(value.value("event")=="prompt"&&service_)service_->cancel();return;}
    const auto type=value.value("event").toString();
    if(type=="snapshot"){
        const auto id=selected().value("id").toString();rows_=value.value("rows").toArray().toVariantList();
        focus_=std::clamp(focus_,0,std::max(0,int(rows_.size())-1));
        for(int i=0;i<rows_.size();++i)if(rows_[i].toMap().value("id").toString()==id){focus_=i;break;}
        if(operation_=="connect" && !bluetooth_)for(int i=0;i<rows_.size();++i) {
            const auto row=rows_[i].toMap();
            if(row.value("connected").toBool() && row.value("title")==target_.value("title") && row.value("security")==target_.value("security")) {
                focus_=i;if(detailsOpen())detail_=row;target_=row;break;
            }
        }
    }else if(type=="progress"){
        if(operation_=="connect")status_=value.value("text").toString();
    }else if(type=="prompt"){
        if(!active_){if(service_)service_->cancel();return;}
        const auto kind=value.value("kind").toString();
        if(kind=="pin"||kind=="passkey"){
            textMode_=kind;emit textRequested(kind=="pin"?"Pairing PIN":"Pairing code",kind=="pin"?16:6,false);
        }else{
            confirmation_=kind=="display"?"display":"pair";
            prompt_=value.value("text").toString();
        }
    }
    emit changed();
}
QString NetworkController::confirmLabel()const{return confirmation_=="display"?"Wait":confirmation_=="forget"?"Forget":confirmation_=="disconnect"?"Disconnect":"Confirm";}
void NetworkController::selectFace(bool bluetooth){
    if(busy_||!prompt_.isEmpty()||!textMode_.isEmpty()||bluetooth_==bluetooth)return;
    bluetooth_=bluetooth;detail_.clear();target_.clear();failed_=false;status_.clear();rows_.clear();focus_=0;run("list");
}
void NetworkController::activate(int index){
    if(!prompt_.isEmpty()){confirm();return;}
    if(busy_||index<0||index>=rows_.size())return;
    focus_=index;const auto row=selected();pending_={{"id",row.value("id").toString()}};
    if(!bluetooth_) {
        if(row.value("connected").toBool() || !row.value("available",true).toBool())showDetails(index);
        else connectWifi(row);
    }else if(row.value("connected").toBool()){
        confirmation_="disconnect";prompt_="Disconnect from "+row.value("title").toString()+"?";
    }else run(!row.value("saved").toBool()?"pair":"connect",pending_);
    emit changed();
}
QVariantMap NetworkController::networkInfo() const {
    if(detail_.value("hidden").toBool())return detail_;
    for(const auto& row:rows_)if(row.toMap().value("id")==detail_.value("id"))return row.toMap();
    auto stale=detail_;stale["available"]=false;stale["connected"]=false;return stale;
}
QVariantList NetworkController::detailActions() const {
    if(!detailsOpen())return {};
    const auto row=networkInfo();QVariantList actions;
    auto add=[&](const QString& id,const QString& title,const QString& detail=QString()){actions.append(QVariantMap{{"id",id},{"title",title},{"detail",detail}});};
    if(row.value("connected").toBool())add("disconnect","Disconnect");
    else if(row.value("available",true).toBool())add("connect",failed_?"Try again":"Join network");
    if(row.value("security")=="wpa-psk" || row.value("security")=="sae")add("password",failed_?"Re-enter password":"Change password");
    if(row.value("saved").toBool()) {
        add("autojoin","Auto-join",row.value("autoconnect",true).toBool()?"On":"Off");
        add("forget","Forget this network");
    }
    if(row.value("hidden").toBool())add("security","Security",row.value("security")=="open"?"None":row.value("security")=="sae"?"WPA3 Personal":"WPA2 Personal");
    return actions;
}
void NetworkController::showDetails(int index) {
    if(bluetooth_ || busy_ || !prompt_.isEmpty() || !textMode_.isEmpty() || index<0 || index>=rows_.size())return;
    focus_=index;detail_=selected();detailFocus_=0;status_.clear();failed_=false;emit changed();
}
void NetworkController::otherNetwork() {
    if(bluetooth_ || busy_ || !prompt_.isEmpty() || !textMode_.isEmpty())return;
    failed_=false;status_.clear();textMode_="ssid";emit textRequested("Hidden network name",32,false);
}
void NetworkController::connectWifi(const QVariantMap& row,bool editPassword) {
    target_=row;pending_={{"id",row.value("id").toString()}};
    if(row.value("hidden").toBool())pending_={{"ssid",row.value("title").toString()},{"security",row.value("security").toString()}};
    if(!row.value("available",true).toBool() && !row.value("connected").toBool()) {status_="Network out of range. Search again when nearby.";failed_=true;emit changed();return;}
    if(!row.value("saved").toBool() && row.value("security")=="unsupported") {status_="Set up enterprise networks in Desktop Mode first.";failed_=true;detail_=row;emit changed();return;}
    if((editPassword || !row.value("saved").toBool()) && row.value("security")!="open") {
        textMode_="password";emit textRequested("Password for "+row.value("title").toString(),64,true);
    }else run("connect",pending_);
}
void NetworkController::activateDetail(const QString& id) {
    if(busy_ || !detailsOpen() || !prompt_.isEmpty() || !textMode_.isEmpty())return;
    bool valid=false;for(const auto& action:detailActions())if(action.toMap().value("id")==id)valid=true;
    if(!valid)return;
    const auto row=networkInfo();
    if(id=="connect" || id=="password")connectWifi(row,id=="password");
    else if(id=="security") {const auto security=row.value("security").toString();detail_["security"]=security=="wpa-psk"?"sae":security=="sae"?"open":"wpa-psk";}
    else if(id=="autojoin")run("autojoin",{{"id",row.value("id").toString()},{"enabled",!row.value("autoconnect",true).toBool()}});
    else if(id=="forget" || id=="disconnect") {pending_={{"id",row.value("id").toString()}};confirmation_=id;prompt_=(id=="forget"?"Forget ":"Disconnect from ")+row.value("title").toString()+"?";}
    emit changed();
}
void NetworkController::confirm(){
    const auto action=confirmation_;
    if(action=="display")return;
    confirmation_.clear();prompt_.clear();
    if(action=="pair"){if(service_)service_->respond({{"accept",true}});}
    else if(action=="forget"||action=="disconnect")run(action,pending_);
    emit changed();
}
void NetworkController::applyText(const QString& text){
    const auto mode=textMode_;textMode_.clear();
    if(mode=="password"){
        const auto bytes=text.toUtf8().size();
        if(!((bytes>=8 && bytes<=63) || (target_.value("security")=="wpa-psk" && QRegularExpression("^[0-9a-fA-F]{64}$").match(text).hasMatch()))) {
            status_="Use 8-63 bytes, or a 64-digit hexadecimal WPA2 key.";failed_=true;detail_=target_;detailFocus_=0;emit changed();return;
        }
        auto value=pending_;value["password"]=text;run("connect",value);
    }else if(mode=="ssid") {
        if(text.toUtf8().isEmpty() || text.toUtf8().size()>32 || text.contains(QChar(0))) {status_="Network name must be 1-32 bytes.";failed_=true;emit changed();return;}
        detail_={{"id","hidden"},{"title",text},{"security","wpa-psk"},{"hidden",true},{"available",true}};detailFocus_=0;emit changed();
    }else if((mode=="pin"||mode=="passkey")&&service_)service_->respond({{"value",text}});
}
void NetworkController::cancelText(){
    if(textMode_=="pin"||textMode_=="passkey"){if(service_)service_->cancel();}
    textMode_.clear();pending_={};emit changed();
}
void NetworkController::dispatch(Action action){
    if(action==Action::Back){
        if(busy_){if(service_)service_->cancel();status_="Cancelling…";emit changed();return;}
        if(!prompt_.isEmpty()){prompt_.clear();confirmation_.clear();pending_={};emit changed();return;}
        if(detailsOpen()){detail_.clear();failed_=false;status_.clear();emit changed();return;}
        emit backRequested();return;
    }
    if(!prompt_.isEmpty()){if(action==Action::Confirm)confirm();return;}
    if(busy_)return;
    if(detailsOpen()) {
        const auto actions=detailActions();
        if(action==Action::Up)detailFocus_=std::max(0,detailFocus_-1);
        if(action==Action::Down)detailFocus_=std::min(std::max(0,int(actions.size())-1),detailFocus_+1);
        if(action==Action::Confirm)activateDetail(actions.value(detailFocus_).toMap().value("id").toString());
        emit changed();return;
    }
    if(!bluetooth_ && (action==Action::ContextMenu || action==Action::LocalAction)){showDetails(focus_);return;}
    if(!bluetooth_ && action==Action::ToggleFavorite){otherNetwork();return;}
    if(action==Action::Left||action==Action::Right){selectFace(!bluetooth_);return;}
    if(action==Action::Secondary){emit radioRequested(bluetooth_?3:2);return;}
    if(action==Action::ToggleContinue){run("scan");return;}
    if(action==Action::LocalAction&&selected().value("saved").toBool()){
        pending_={{"id",selected().value("id").toString()}};confirmation_="forget";
        prompt_="Forget "+selected().value("title").toString()+"?";
    }
    if(action==Action::Up)focus_=std::max(0,focus_-1);
    if(action==Action::Down)focus_=std::min(std::max(0,int(rows_.size())-1),focus_+1);
    if(action==Action::Confirm){activate(focus_);return;}
    emit changed();
}
}
