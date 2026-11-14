#include "AppsController.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QCryptographicHash>
#include <QUrl>
#include <algorithm>
#include <memory>
#include <QElapsedTimer>

namespace trainer {
AppsController::AppsController(QObject* parent):QObject(parent) {
    struct Recovery {int attempts=0;QElapsedTimer healthy;};
    const auto recovery=std::make_shared<Recovery>();
    webStartTimeout_.setSingleShot(true);webStartTimeout_.setInterval(15000);
    connect(&webStartTimeout_,&QTimer::timeout,this,[this]{
        if(!webPending_)return;webPending_=false;queuedWebUrl_=QUrl{};
        status_="Application connection did not become ready. Try again.";emit webOpenFailed(status_);emit changed();
    });
    heartbeat_.setInterval(500);
    connect(&heartbeat_,&QTimer::timeout,this,[this,recovery]{
        if(process_.state()==QProcess::NotRunning){start(python_,helper_);return;}
        if(recovery->healthy.isValid() && recovery->healthy.elapsed()>30000)recovery->attempts=0;
        send({{"command","ping"}});
    });
    connect(this,&AppsController::commandRequested,this,&AppsController::send);
    connect(&process_,&QProcess::started,this,[this,recovery]{recovery->healthy.start();heartbeat_.start(500);});
    connect(&process_,&QProcess::readyReadStandardError,this,[this]{process_.readAllStandardError();});
    connect(&process_,&QProcess::readyReadStandardOutput,this,[this]{
        buffer_+=process_.readAllStandardOutput();
        if(buffer_.size()>2*1024*1024){process_.kill();return;}
        while(buffer_.contains('\n')) {
            const auto end=buffer_.indexOf('\n');const auto packet=QJsonDocument::fromJson(buffer_.left(end));buffer_.remove(0,end+1);
            if(packet.isObject())accept(packet.object());
        }
    });
    const auto lost=[this,recovery]{
        const bool foreground=!current_.isEmpty(), launching=!launching_.isEmpty(), web=webPending_, reconnectable=ready_||recovery->attempts>0;
        heartbeat_.stop();ready_=false;controls_=false;current_.clear();processId_=0;launching_.clear();
        status_="Application connection stopped. Open Apps again to reconnect.";
        if(reconnectable && !helper_.isEmpty() && recovery->attempts++<3) {
            status_="Reconnecting application controls…";heartbeat_.start(1500);
        }
        if(webPending_){webPending_=false;queuedWebUrl_=QUrl{};webStartTimeout_.stop();emit webOpenFailed(status_);}
        if(launching&&!foreground&&!web)emit launchFailed(status_);
        if(foreground)emit shellRequested();
        emit changed();
    };
    connect(&process_,&QProcess::finished,this,lost);
    connect(&process_,&QProcess::errorOccurred,this,[lost](QProcess::ProcessError error){if(error==QProcess::FailedToStart)lost();});
}
AppsController::~AppsController(){
    disconnect(&process_,nullptr,this,nullptr);
    heartbeat_.stop();webStartTimeout_.stop();process_.closeWriteChannel();
    if(process_.state()!=QProcess::NotRunning&&!process_.waitForFinished(500)){process_.kill();process_.waitForFinished(500);}
}
void AppsController::configure(const QString& directory,const QString& owner) {
    preferences_.clear();favorites_.clear();hiddenIds_.clear();leave();
    if(!owner.isEmpty()&&!directory.isEmpty()) {
        const auto key=QString::fromLatin1(QCryptographicHash::hash(owner.toUtf8(),QCryptographicHash::Sha256).toHex());
        preferences_=QDir(directory).filePath("apps/"+key+".json");
        QFile file(preferences_);
        if(file.exists()) {
            if(file.size()>1024*1024||!file.open(QIODevice::ReadOnly))status_="Could not read your application preferences.";
            else {
                const auto object=QJsonDocument::fromJson(file.readAll()).object();
                if(object["version"].toInt()!=1)status_="Application preferences need recovery.";
                else {
                    for(const auto& value:object["favorites"].toArray())favorites_.insert(value.toString());
                    for(const auto& value:object["hidden"].toArray())hiddenIds_.insert(value.toString());
                }
            }
        }
    }
    normalize();emit changed();
}
void AppsController::start(const QString& python,const QString& helper) {
    if(process_.state()!=QProcess::NotRunning)return;
    python_=python;helper_=helper;
    buffer_.clear();status_="Loading applications…";
    process_.start(python,{helper});emit changed();
}
void AppsController::failLaunch(const QString& message) {
    status_=message;emit launchFailed(message);emit changed();
}
void AppsController::send(const QJsonObject& packet) {
    if(process_.state()!=QProcess::Running)return;
    if(process_.bytesToWrite()>65536){process_.kill();return;}
    process_.write(QJsonDocument(packet).toJson(QJsonDocument::Compact)+'\n');
}
void AppsController::accept(const QJsonObject& packet) {
    const auto previous=railFocused_?selected():QString{};
    const auto previousGrid=railFocused_?QString{}:selected();
    const auto event=packet["event"].toString();
    if(event=="catalogue") {
        catalogue_.clear();QSet<QString> ids;
        for(const auto& value:packet["rows"].toArray()) {
            const auto row=value.toObject().toVariantMap();const auto id=row.value("id").toString();
            if(id.isEmpty()||ids.contains(id)||row.value("name").toString().isEmpty())continue;
            ids.insert(id);catalogue_.append(row);
        }
        std::sort(catalogue_.begin(),catalogue_.end(),[](const QVariant& a,const QVariant& b){return QString::localeAwareCompare(a.toMap()["name"].toString(),b.toMap()["name"].toString())<0;});
    } else if(event.startsWith("keyboard")) {controls_=false;emit keyboardEvent(packet);}
    else if(event=="ready") {
        ready_=true;status_.clear();
        if(!queuedWebUrl_.isEmpty()){
            const auto url=queuedWebUrl_;queuedWebUrl_=QUrl{};webStartTimeout_.stop();
            const auto error=webLaunchGuard?webLaunchGuard():launchGuard?launchGuard():QString{};
            if(!error.isEmpty()){webPending_=false;status_=error;emit webOpenFailed(error);}
            else emit commandRequested({{"command","open-url"},{"url",url.toString(QUrl::FullyEncoded)}});
        }
    }
    else if(event=="state") {
        running_.clear();for(const auto& value:packet["running"].toArray())running_.insert(value.toString());
        current_=packet["current"].toString();launching_=packet["launching"].toString();
        if(current_.isEmpty())controls_=false;
    } else if(event=="foreground") {webPending_=false;launching_.clear();status_.clear();current_=packet["id"].toString();processId_=packet["pid"].toVariant().toLongLong();controls_=false;emit foregroundRequested();}
    else if(event=="shell") {current_.clear();processId_=0;controls_=false;emit shellRequested();}
    else if(event=="controls") {controls_=true;controlFocus_=0;emit keyboardEvent({{"event","keyboard-closed"}});}
    else if(event=="action") {
        const auto name=packet["action"].toString();
        if(name=="confirm")control(controlFocus_);
        else if(name=="back"||name=="home")control(0);
        else if(name=="left"||name=="up")controlFocus_=std::max(0,controlFocus_-1);
        else if(name=="right"||name=="down")controlFocus_=std::min(2,controlFocus_+1);
    } else if(event=="error"){
        launching_.clear();status_=packet["message"].toString();
        if(webPending_){webPending_=false;queuedWebUrl_=QUrl{};webStartTimeout_.stop();emit webOpenFailed(status_);}
        else if(!current_.isEmpty())emit commandRequested({{"command","controls"}});
        else emit launchFailed(status_);
    }
    normalize(previous,previousGrid);emit changed();
}
QVariantMap AppsController::decorated(const QVariantMap& source) const {
    auto row=source;const auto id=row["id"].toString();row["favorite"]=favorites_.contains(id);
    row["hidden"]=hiddenIds_.contains(id);row["running"]=running_.contains(id)||current_==id;row["launching"]=launching_==id;
    row["minimized"]=row["running"].toBool()&&current_!=id;
    if(!game_.isEmpty() && row["gameId"]==game_["gameId"]) {row["running"]=true;row["minimized"]=gameMinimized_;}
    return row;
}
void AppsController::setGameState(const QVariantMap& game,bool minimized) {
    if(game_==game && gameMinimized_==minimized)return;
    game_=game;gameMinimized_=minimized;normalize();emit changed();
}
QVariantList AppsController::rows() const {
    QVariantList result;for(const auto& value:catalogue_)if(hiddenIds_.contains(value.toMap()["id"].toString())==hidden_)result.append(decorated(value.toMap()));return result;
}
QVariantList AppsController::rail() const {
    QVariantList result;QSet<QString> pinned;
    for(const auto& value:catalogue_) {
        const auto id=value.toMap()["id"].toString();
        if(favorites_.contains(id)&&(!hiddenIds_.contains(id)||decorated(value.toMap())["running"].toBool())&&pinned.size()<favoriteCapacity_) {
            auto row=decorated(value.toMap());row["railPinned"]=true;result.append(row);pinned.insert(id);
        }
    }
    for(const auto& value:catalogue_) {
        const auto id=value.toMap()["id"].toString();
        if((decorated(value.toMap())["running"].toBool()||launching_==id)&&!pinned.contains(id)) {
            auto row=decorated(value.toMap());row["railPinned"]=false;result.append(row);
        }
    }
    if(!game_.isEmpty() && std::none_of(result.cbegin(),result.cend(),[&](const QVariant& row){return row.toMap()["gameId"]==game_["gameId"];})) {
        auto row=decorated(game_);row["railPinned"]=false;result.append(row);
    }
    QSet<QString> games;
    result.erase(std::remove_if(result.begin(),result.end(),[&](const QVariant& value){
        const auto id=value.toMap()["gameId"].toString();if(id.isEmpty())return false;
        if(games.contains(id))return true;games.insert(id);return false;
    }),result.end());
    return result;
}
int AppsController::visibleFavoriteCount() const {
    int count=0;for(const auto& value:catalogue_) {
        const auto id=value.toMap()["id"].toString();
        if(favorites_.contains(id)&&!hiddenIds_.contains(id))++count;
    }return count;
}
void AppsController::setFavoriteCapacity(int value) {
    value=std::max(0,value);if(value==favoriteCapacity_)return;
    const auto previous=railFocused_?selected():QString{};
    favoriteCapacity_=value;normalize(previous);emit changed();
}
QString AppsController::currentName() const {for(const auto& v:catalogue_)if(v.toMap()["id"]==current_)return v.toMap()["name"].toString();return "Application";}
QString AppsController::selected() const{return (railFocused_?rail():rows()).value(railFocused_?railFocus_:focus_).toMap()["id"].toString();}
void AppsController::normalize(const QString& preferredRailId,const QString& preferredGridId){
    const auto grid=rows();
    for(int i=0;!preferredGridId.isEmpty()&&i<grid.size();++i)if(grid[i].toMap()["id"]==preferredGridId){focus_=i;break;}
    focus_=std::clamp(focus_,0,std::max(0,int(rows().size())-1));
    const auto items=rail();
    for(int i=0;!preferredRailId.isEmpty()&&i<items.size();++i)if(items[i].toMap()["id"].toString()==preferredRailId){railFocus_=i;break;}
    railFocus_=std::clamp(railFocus_,0,std::max(0,int(items.size())-1));if(items.isEmpty())railFocused_=false;
}
void AppsController::openFile(const QString& url) {
    if(!ready_){failLaunch("Application controls are unavailable. Open Apps to reconnect.");return;}
    if(!launching_.isEmpty())return;
    if(launchGuard){const auto error=launchGuard();if(!error.isEmpty()){failLaunch(error);return;}}
    launching_="@file";status_.clear();emit changed();emit commandRequested({{"command","open-file"},{"url",url}});
}
bool AppsController::openWebUrl(const QUrl& url) {
    if(webPending_||!launching_.isEmpty()||!url.isValid()||url.scheme()!="https"||url.host().isEmpty()||!url.userInfo().isEmpty())return false;
    if(webLaunchGuard || launchGuard){const auto error=webLaunchGuard?webLaunchGuard():launchGuard();if(!error.isEmpty()){status_=error;emit changed();return false;}}
    if(!ready_){
        if(python_.isEmpty()||helper_.isEmpty())return false;
        webPending_=true;queuedWebUrl_=url;webStartTimeout_.start();refresh();return true;
    }
    webPending_=true;status_.clear();emit commandRequested({{"command","open-url"},{"url",url.toString(QUrl::FullyEncoded)}});emit changed();return true;
}
void AppsController::watchInstaller(qint64 pid,const QString& title) {
    if(ready_&&pid>1)emit commandRequested({{"command","watch-installer"},{"pid",QString::number(pid)},{"title",title.left(96)}});
}
void AppsController::finishInstaller() {emit commandRequested({{"command","finish-installer"}});}
void AppsController::resumeInstaller() {emit commandRequested({{"command","resume-installer"}});}
void AppsController::refresh(){
    if(process_.state()==QProcess::NotRunning&&!helper_.isEmpty()){heartbeat_.stop();start(python_,helper_);return;}
    emit commandRequested({{"command","refresh"}});
}
void AppsController::select(int index,bool rail){const auto list=rail?this->rail():rows();if(index<0||index>=list.size())return;railFocused_=rail;(rail?railFocus_:focus_)=index;emit changed();}
void AppsController::openDesktopId(const QString& id) {
    if(id.isEmpty()||!launching_.isEmpty())return;
    for(const auto& value:catalogue_)if(value.toMap()["id"]==id && !value.toMap()["gameId"].toString().isEmpty()) {
        const auto error=launchManagedGame?launchManagedGame(value.toMap()["gameId"].toString()):QString("Game controls are unavailable.");
        if(!error.isEmpty())failLaunch(error);return;
    }
    if(!ready_){failLaunch("Application controls are unavailable. Open Apps to reconnect.");return;}
    if(launchGuard){const auto error=launchGuard();if(!error.isEmpty()){failLaunch(error);return;}}
    launching_=id;status_.clear();emit changed();
    emit commandRequested({{"command","refresh"}});
    emit commandRequested({{"command","launch"},{"id",id}});
}
void AppsController::open(int index,bool rail) {
    if(index<0||index>=(rail?this->rail():rows()).size())return;
    select(index,rail);const auto id=selected();if(id.isEmpty()||!launching_.isEmpty())return;
    const auto game=(rail?this->rail():rows())[index].toMap()["gameId"].toString();
    if(!game.isEmpty()) {
        const auto error=launchManagedGame?launchManagedGame(game):QString("Game controls are unavailable.");
        if(!error.isEmpty())failLaunch(error);return;
    }
    if(!ready_){failLaunch("Application controls are unavailable. Open Apps to reconnect.");return;}
    if(launchGuard){const auto error=launchGuard();if(!error.isEmpty()){failLaunch(error);return;}}
    launching_=id;status_.clear();emit changed();emit commandRequested({{"command","launch"},{"id",id}});
}
void AppsController::options(int index,bool rail){if(index<0||index>=(rail?this->rail():rows()).size())return;select(index,rail);menuId_=selected();menuFocus_=0;emit changed();}
QVariantList AppsController::menu() const {
    if(menuId_.isEmpty())return {};
    if(menuId_.startsWith("game:"))return {QVariantMap{{"label","Back"}}};
    return {QVariantMap{{"label",favorites_.contains(menuId_)?"Remove favorite":visibleFavoriteCount()>=favoriteCapacity_?"Favorites full - remove one":"Add to favorites"}},
            QVariantMap{{"label",hiddenIds_.contains(menuId_)?"Show in Apps":"Hide from Apps"}},
            QVariantMap{{"label",hidden_?"All applications":"Hidden applications"}},QVariantMap{{"label","Back"}}};
}
bool AppsController::persist(const QSet<QString>& favorites,const QSet<QString>& hidden) {
    if(preferences_.isEmpty()) {status_="Choose a Trainer to save application preferences.";return false;}
    QDir().mkpath(QFileInfo(preferences_).absolutePath());QSaveFile file(preferences_);
    const auto bytes=QJsonDocument(QJsonObject{{"version",1},{"favorites",QJsonArray::fromStringList(favorites.values())},{"hidden",QJsonArray::fromStringList(hidden.values())}}).toJson();
    if(!file.open(QIODevice::WriteOnly)||file.write(bytes)!=bytes.size()||!file.commit()){status_="Could not save application preferences. Your previous settings are unchanged.";return false;}
    favorites_=favorites;hiddenIds_=hidden;status_.clear();return true;
}
void AppsController::menuAction(int index) {
    if(menuId_.isEmpty())return;
    if(menuId_.startsWith("game:")){menuId_.clear();emit changed();return;}
    const auto previous=railFocused_?selected():QString{};
    auto favorites=favorites_,hidden=hiddenIds_;
    if(index==0){
        if(!favorites.remove(menuId_)) {
            if(visibleFavoriteCount()>=favoriteCapacity_) {status_="Favorites are full. Remove a favorite first.";emit changed();return;}
            favorites.insert(menuId_);
        }persist(favorites,hidden);
    }
    else if(index==1){if(!hidden.remove(menuId_))hidden.insert(menuId_);persist(favorites,hidden);}
    else if(index==2){showHidden();return;}
    else if(index!=3)return;
    menuId_.clear();normalize(previous);emit changed();
}
void AppsController::showHidden(){hidden_=!hidden_;focus_=0;railFocused_=false;menuId_.clear();emit changed();}
void AppsController::leave(bool preserveLocation){menuId_.clear();if(!preserveLocation){hidden_=false;railFocused_=false;}normalize();emit changed();}
void AppsController::showControls(){if(!current_.isEmpty()){status_.clear();emit commandRequested({{"command","controls"}});}}
void AppsController::control(int index) {
    if(current_.isEmpty()||index<0||index>2)return;
    controls_=false;status_.clear();
    emit commandRequested({{"command",index==1?"minimize":index==2?"close":"resume"},{"id",current_}});emit changed();
}
void AppsController::dispatch(Action action,bool quick) {
    if(quick && menuId_.isEmpty()) {
        // An empty/changed quick tray must never activate an invisible Apps-grid item.
        if(rail().isEmpty())return;
        railFocused_=true;
        if(action==Action::Confirm){open(railFocus_,true);return;}
        if(action==Action::LocalAction){options(railFocus_,true);return;}
        if(action==Action::Left || action==Action::Right) {
            railFocus_+=action==Action::Right?1:-1;normalize();emit changed();
        }
        return;
    }
    if(!menuId_.isEmpty()) {
        if(action==Action::Back)menuId_.clear();
        else if(action==Action::Up)menuFocus_=std::max(0,menuFocus_-1);
        else if(action==Action::Down)menuFocus_=std::min(int(menu().size())-1,menuFocus_+1);
        else if(action==Action::Confirm){menuAction(menuFocus_);return;}
    } else if(action==Action::Back) {if(hidden_)showHidden();else emit homeRequested();}
    else if(action==Action::Secondary){showHidden();return;}
    else if(action==Action::ToggleContinue){railFocused_=!railFocused_&&!rail().isEmpty();}
    else if(action==Action::LocalAction){options(railFocused_?railFocus_:focus_,railFocused_);return;}
    else if(action==Action::Confirm){open(railFocused_?railFocus_:focus_,railFocused_);return;}
    else {
        const int delta=action==Action::Left?-1:action==Action::Right?1:action==Action::Up?(railFocused_?-1:-5):action==Action::Down?(railFocused_?1:5):0;
        (railFocused_?railFocus_:focus_)+=delta;normalize();
    }emit changed();
}
}
