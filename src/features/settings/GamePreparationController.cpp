#include "GamePreparationController.h"
#include <QtConcurrent>
#include <algorithm>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include "core/repository/RomPlatforms.h"

namespace trainer {
GamePreparationController::GamePreparationController(QObject* parent):QObject(parent) {
    connect(&setup_,&ProcessService::started,this,[this]{emit setupStarted(setup_.processId(),platformTitle()+" setup");emit changed();});
    connect(&setup_,&ProcessService::finished,this,[this](int code,bool crashed,const QString& error){
        busy_=false;emit setupFinished();
        status_=!error.isEmpty()?error:crashed||code!=0?QString("Emulator setup ended without success. Open it again to review its state."):QString("Emulator setup closed. Checking its files again…");
        taskDetail_=status_;emit changed();emit installed();refresh();
    });
    connect(&picker_,&FilePickerController::changed,this,&GamePreparationController::changed);
    connect(&picker_,&FilePickerController::selected,this,&GamePreparationController::importSelected);
    connect(&picker_,&FilePickerController::cancelled,this,[this]{picking_.clear();});
    progress_.setInterval(200);connect(&progress_,&QTimer::timeout,this,[this]{emit tasksChanged();emit changed();});
}
GamePreparationController::~GamePreparationController(){cancel_=true;future_.waitForFinished();}
void GamePreparationController::configure(QString directory,QHash<QString,QJsonObject> profiles){
    if(directory_==directory&&profiles_==profiles)return;
    const bool hadRows=!rows_.isEmpty();
    picker_.cancel();if(busy_)cancel_=true;directory_=directory;profiles_=profiles;files_.clear();rows_.clear();if(packReport_.isEmpty())selected_.clear();
    status_="Runtime configuration changed. Check files again before importing.";emit changed();
    if(hadRows&&!busy_)refresh();
}
QVariantList GamePreparationController::rows() const {QVariantList result;for(const auto& v:rows_)if(group_.isEmpty()||v.toMap()["group"]==group_)result<<v;return result;}
QVariantList GamePreparationController::fileRows() const {QVariantList result;for(const auto& v:rows())if(v.toMap().contains("filename"))result<<v;return result;}
namespace {
QString platformName(const QString& id){for(const auto& p:romPlatforms())if(p.id==id)return p.name;return id.startsWith("core:")?id.mid(5):id;}
}
QVariantList GamePreparationController::platforms() const {
    QVariantList result;
    for(const auto& id:groups()) {
        int total=0,found=0,requiredMissing=0;bool unknown=false,noBios=false,missingRuntime=false,online=false;
        for(const auto& v:rows_){const auto r=v.toMap();if(r["group"]!=id)continue;
            if(r.contains("filename")){++total;if(r["checked"].toBool())++found;else if(!r["optional"].toBool())++requiredMissing;}
            else {unknown|=r["state"]=="Not described"||r["state"]=="Needs setup";noBios|=r["state"]=="No files listed";missingRuntime|=r["state"]=="Missing runtime";online|=r["state"]=="Online setup";}}
        const auto state=missingRuntime||(total>0&&found==0)?"missing":unknown||requiredMissing||(!total&&!noBios)?"partial":"ready";
        result<<QVariantMap{{"id",id},{"title",platformName(id)},{"state",state},{"onlineWarning",online},
            {"detail",missingRuntime?QString("Emulator missing"):total?QString("%1 / %2 files").arg(found).arg(total):noBios?QString("No BIOS needed"):QString("Needs preparation")}};
    }
    std::sort(result.begin(),result.end(),[](const auto& a,const auto& b){return a.toMap()["title"].toString()<b.toMap()["title"].toString();});return result;
}
QString GamePreparationController::platformTitle() const{return platformName(group_);}
QString GamePreparationController::platformNote() const{QStringList notes;for(const auto& v:rows()){const auto r=v.toMap();if(!r.contains("filename")&&r["state"]!="Online setup")notes<<r["detail"].toString();}return notes.join('\n');}
bool GamePreparationController::hasOnline() const{return QStringList{"wii","n3ds","wiiu"}.contains(group_);}
QString GamePreparationController::onlineStatus() const{for(const auto& v:rows())if(v.toMap()["state"]=="Online setup")return v.toMap()["detail"].toString();return {};}
QStringList GamePreparationController::groups() const {QStringList result;for(const auto& v:rows_){const auto group=v.toMap()["group"].toString();if(!result.contains(group))result<<group;}result.sort();return result;}
QVariantMap GamePreparationController::selected() const {if(selected_=="@pack-report")return {{"title","BIOS pack import result"},{"group","Last import"},{"state",taskState_},{"detail",packReport_},{"importable",false}};for(const auto& v:rows_)if(v.toMap()["id"]==selected_)return v.toMap();return {};}
QVariantList GamePreparationController::tasks() const {
    if(taskName_.isEmpty())return {};
    QVariantMap row{{"id","firmware"},{"title",taskName_},{"kind","file-operation"},{"state",taskState_},
        {"detail",taskDetail_},{"progress",total_>0?double(received_)/double(total_):0.0},{"terminal",taskState_!="running"},
        {"actions",taskState_=="running"?QVariantList{QVariantMap{{"id","cancel"},{"label","Cancel import"}}}:QVariantList{}}};
    if(!packJob_){row["received"]=received_.load();row["total"]=total_.load();}return {row};
}
QJsonObject GamePreparationController::setupProfile() const {
    if(!setupAdapter_.isEmpty())return profiles_.value(setupAdapter_);
    QStringList ids=profiles_.keys();ids.sort();
    for(const auto& id:ids)if(id!="retroarch") {
        const auto p=profiles_[id];if(p["validatedPlatforms"].toArray().contains(group_)&&!p["setupProgram"].toString().isEmpty())return p;
    }
    const auto core=romCore(group_);const auto ra=profiles_.value("retroarch");
    if(core.isEmpty() || QDir(ra["coresDirectory"].toString()).entryList({core+"_libretro.*"},QDir::Files).isEmpty())return {};
    return ra;
}
bool GamePreparationController::setupAvailable() const {
    const auto p=setupProfile();return QFileInfo(p["setupProgram"].toString()).isAbsolute()&&QFileInfo(p["setupProgram"].toString()).isExecutable()&&p["setupArguments"].isArray();
}
void GamePreparationController::openSetup() {
    if(setup_.active()){emit resumeSetup();return;}
    if(busy_||!setupAvailable())return;
    if(canImport&&!canImport()){status_="Finish the game or current operation before opening emulator setup.";emit changed();return;}
    if(setupGuard){const auto error=setupGuard();if(!error.isEmpty()){status_=error;emit changed();return;}}
    const auto p=setupProfile();ProcessCommand command;command.program=p["setupProgram"].toString();
    const auto args=p["setupArguments"].toArray();if(args.size()>32)return;
    for(const auto& v:args){if(!v.isString()||v.toString().contains(QChar::Null))return;command.arguments<<v.toString();}
    command.emulatorRuntime=true;busy_=true;status_="Use the emulator's interface to install firmware or game packages, then close it and check again.";
    if(!setup_.start(command)){busy_=false;status_="The emulator setup could not start. Check Software setup.";}
    emit changed();
}
void GamePreparationController::begin(const QString& platform,const QString& adapter){setupAdapter_=adapter;picker_.cancel();if(!platform.isEmpty())group_=platform;focus_=100;refresh();}
void GamePreparationController::refresh() {
    if(busy_)return;busy_=true;cancel_=false;status_="Checking configured emulators and their files…";emit changed();
    const auto profiles=profiles_;const auto directory=directory_;
    future_=QtConcurrent::run([this,profiles,directory]{
        const auto inventory=gamePreparation::inventory(profiles,directory);QVariantList rows=inventory.notes;
        for(const auto& file:inventory.files){if(cancel_)break;rows<<gamePreparation::inspect(file,cancel_);}
        std::stable_sort(rows.begin(),rows.end(),[](const QVariant& a,const QVariant& b){const auto x=a.toMap(),y=b.toMap();return x["group"]==y["group"]?x["title"].toString()<y["title"].toString():x["group"].toString()<y["group"].toString();});
        const bool cancelled=cancel_;
        QMetaObject::invokeMethod(this,[this,inventory,rows,cancelled]{
            busy_=false;if(!cancelled){files_=inventory.files;rows_=rows;if(!groups().contains(group_))group_=platforms().value(0).toMap()["id"].toString();if(selected().isEmpty())selected_=fileRows().value(0).toMap()["id"].toString();}
            status_=cancelled?"Check cancelled.":taskDetail_;emit platformSelected(group_);emit changed();
        },Qt::QueuedConnection);
    });
}
void GamePreparationController::choose() {
    if(busy_||!selected()["importable"].toBool())return;
    if(canImport&&!canImport()){status_="Finish the game or current storage operation before importing firmware.";emit changed();return;}
    picking_=selected_;picker_.begin({},selected()["directory"].toBool());
}
void GamePreparationController::choosePack(){
    if(busy_)return;
    if(canImport&&!canImport()){status_="Finish the game or current storage operation before importing a BIOS pack.";emit changed();return;}
    picking_="@pack";picker_.begin();
}
void GamePreparationController::importSelected(const QString& source) {
    const auto id=picking_;picking_.clear();if(id.isEmpty()||busy_)return;
    if(canImport&&!canImport()){status_="The runtime is now busy. No file was changed; try again after it finishes.";emit changed();return;}
    if(id=="@pack"){importPack(source);return;}
    const auto found=std::find_if(files_.cbegin(),files_.cend(),[&](const auto& f){return f.id==id;});if(found==files_.cend())return;
    QFile input(source);if(!found->directory&&input.open(QIODevice::ReadOnly)){
        const auto header=input.read(8);const bool archive=header.startsWith("PK\x03\x04")||header.startsWith("PK\x05\x06")||header.startsWith("7z\xBC\xAF\x27\x1C")||header.startsWith("Rar!\x1A\x07");
        if(archive&&QFileInfo(source).fileName().compare(QFileInfo(found->name).fileName(),Qt::CaseInsensitive)!=0){input.close();importPack(source);return;}
    }
    const auto file=*found;packJob_=false;busy_=true;cancel_=false;received_=0;total_=0;taskName_="Import "+file.name;taskState_="running";taskDetail_="Checking and copying your file";status_="Import continues in the background. You can leave this screen.";progress_.start();emit changed();emit tasksChanged();
    const auto directory=directory_;const auto profiles=profiles_;
    future_=QtConcurrent::run([this,file,source,directory,profiles]{
        const auto current=gamePreparation::inventory(profiles,directory);
        const bool same=std::any_of(current.files.cbegin(),current.files.cend(),[&](const auto& f){return f.id==file.id&&f.root==file.root&&f.name==file.name&&f.md5==file.md5&&f.size==file.size&&f.directory==file.directory;});
        auto error=same?gamePreparation::importFile(file,source,cancel_,[this](qint64 n,qint64 total){received_=n;total_=total;}):QString("The emulator's firmware location changed. Refresh preparation and select the file again.");
        const bool copied=error.isEmpty();if(copied)error=gamePreparation::registerDiscFirmware(directory,cancel_);
        QMetaObject::invokeMethod(this,[this,error,copied]{busy_=false;progress_.stop();taskState_=error.isEmpty()?"done":"error";taskDetail_=error.isEmpty()?"File installed. Original selected file was kept.":error;status_=taskDetail_;emit changed();emit tasksChanged();if(copied){emit installed();refresh();}},Qt::QueuedConnection);
    });
}
void GamePreparationController::importPack(const QString& source) {
    packJob_=true;busy_=true;cancel_=false;received_=0;total_=100;taskName_="Import BIOS pack";taskState_="running";taskDetail_="Recognizing matching BIOS and system files";
    status_="Importing matching requirements. On success the source archive goes to Trash; errors keep it.";progress_.start();emit changed();emit tasksChanged();
    const auto profiles=profiles_;const auto directory=directory_;
    future_=QtConcurrent::run([this,profiles,directory,source]{
        const auto inventory=gamePreparation::inventory(profiles,directory);
        const auto result=gamePreparation::importPack(inventory,source,cancel_,[this](qint64 n,qint64 total){received_=n;total_=total;},true,[&]{return gamePreparation::registerDiscFirmware(directory,cancel_);});
        QMetaObject::invokeMethod(this,[this,result]{busy_=false;progress_.stop();taskState_=result.problems.isEmpty()?"done":"error";taskDetail_=packReport_=result.summary();status_=QString("%1 installed · %2 already present").arg(result.installed).arg(result.present);selected_="@pack-report";focus_=100;emit changed();emit tasksChanged();if(result.installed)emit installed();refresh();},Qt::QueuedConnection);
    });
}
void GamePreparationController::cancel(){cancel_=true;if(setup_.active())setup_.stop();}
void GamePreparationController::close(){if(setup_.active()){status_="Close the emulator setup first, or use Return to emulator.";emit changed();return;}picker_.cancel();emit closeRequested();}
void GamePreparationController::select(int index){const auto list=rows();if(index<0||index>=list.size())return;selected_=list[index].toMap()["id"].toString();const auto files=fileRows();for(int n=0;n<files.size();++n)if(files[n].toMap()["id"]==selected_)focus_=1000+n;emit changed();}
void GamePreparationController::selectGroup(const QString& value){const auto list=platforms();for(int n=0;n<list.size();++n)if(list[n].toMap()["id"]==value){selectPlatform(n);return;}}
void GamePreparationController::selectPlatform(int index){const auto list=platforms();if(index<0||index>=list.size())return;if(group_!=list[index].toMap()["id"].toString())setupAdapter_.clear();group_=list[index].toMap()["id"].toString();selected_=fileRows().value(0).toMap()["id"].toString();focus_=100+index;emit platformSelected(group_);emit changed();}
void GamePreparationController::importRequirement(int index){const auto list=fileRows();if(index<0||index>=list.size())return;selected_=list[index].toMap()["id"].toString();focus_=1000+index;choose();emit changed();}
void GamePreparationController::onlineAction(int index){if(!hasOnline()||index<0||index>3||busy_)return;focus_=2000+index;emit onlineActionRequested(index+1);emit changed();}
void GamePreparationController::activate(int index) {
    if(index>=2000){onlineAction(index-2000);return;}if(index>=1000){importRequirement(index-1000);return;}if(index>=100){selectPlatform(index-100);return;}
    focus_=index;if(index==3){openSetup();return;}if(index==0)choosePack();if(index==1){if(busy_)cancel();else refresh();}if(index==2)close();emit changed();
}
void GamePreparationController::dispatch(Action a) {
    if(picker_.isOpen()){picker_.dispatch(a);return;}
    if(a==Action::Back){close();return;}
    if(a==Action::ToggleFavorite){openSetup();return;}
    if(a==Action::ScrollUp||a==Action::ScrollDown){emit scrollRequested(a==Action::ScrollDown?1:-1);return;}
    const auto systems=platforms();int system=0;for(int n=0;n<systems.size();++n)if(systems[n].toMap()["id"]==group_)system=n;
    if(a==Action::PreviousFace||a==Action::NextFace){if(!systems.isEmpty())selectPlatform((system+systems.size()+(a==Action::PreviousFace?-1:1))%systems.size());return;}
    if(focus_<100){if(a==Action::Left||a==Action::Right)focus_=std::clamp(focus_+(a==Action::Left?-1:1),0,3);if(a==Action::Down)selectPlatform(system);}
    else if(focus_<1000){if(a==Action::Up){if(system==0)focus_=0;else selectPlatform(system-1);}if(a==Action::Down)selectPlatform(std::min(system+1,int(systems.size())-1));if(a==Action::Right||a==Action::Confirm){focus_=!fileRows().isEmpty()?1000:hasOnline()?2000:100+system;emit changed();return;}}
    else if(focus_<2000){const int index=focus_-1000;if(a==Action::Up)focus_=index?focus_-1:0;if(a==Action::Down){if(index+1<fileRows().size())++focus_;else if(hasOnline())focus_=2000;}if(a==Action::Left)focus_=100+system;}
    else {if(a==Action::Up)focus_=focus_>2000?focus_-1:fileRows().isEmpty()?0:1000+fileRows().size()-1;if(a==Action::Down)focus_=std::min(2003,focus_+1);if(a==Action::Left)focus_=100+system;}
    if(a==Action::Confirm)activate(focus_);emit changed();
}
}
