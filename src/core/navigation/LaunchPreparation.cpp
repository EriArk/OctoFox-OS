#include "LaunchPreparation.h"
#include <QFileInfo>

namespace trainer {
LaunchPreparation::~LaunchPreparation() { if(worker_){worker_->wait();delete worker_;} }
void LaunchPreparation::fail(const QString& error, const QString& repair) {
    const bool cancelled=cancelling_;busy_=false;cancelling_=false;stage_.clear();emit changed();
    if(!playing_)emit checked(adventureId_,{{"state",cancelled?"cancelled":"needs-setup"},{"detail",cancelled?"Check cancelled. Choose Check again to continue.":error},{"repair",repair},{"canPlay",false}});
    else if(!cancelled&&!error.isEmpty()) {
        if(!adventureId_.isEmpty() && library_.registration(adventureId_))emit preparationRequired(adventureId_,{{"state","needs-setup"},{"detail",error},{"repair",repair},{"canPlay",false}});
        emit messageRequested(error);
    }
}
void LaunchPreparation::cancel() {if(busy_&&!cancelling_){cancelling_=true;emit changed();}}
void LaunchPreparation::launch(const QString& id) { begin(id,true); }
void LaunchPreparation::check(const QString& id) { begin(id,false); }
void LaunchPreparation::begin(const QString& id, bool play) {
    if(busy_)return;
    playing_=play;adventureId_=id;
    const auto record=library_.registration(id);
    if(!record || record->removed){fail("This game is not installed.");return;}
    auto prepared=*record;
    // Keep explicit/custom routes and all personal metadata intact.
    if(prepared.adventure.adapterId=="unconfigured")adapter_.prepareInstallation(prepared);
    busy_=true;cancelling_=false;adventureId_=id;stage_="Checking game and emulator…";emit changed();
    if(worker_){worker_->wait();delete worker_;}
    worker_=QThread::create([this,record=*record,prepared,requirements=requirements] {
        const QFileInfo file(record.contentPath);
        const bool available=file.isAbsolute() && file.isFile() && file.isReadable() && file.size()>0;
        auto issue=available?adapter_.verifyInstallation(prepared):QString("The game file is missing or unreadable. Reconnect its storage or choose its current file.");
        QString repair=available?"software":"file";
        QVariantMap readiness;
        if(available && requirements) {
            readiness=requirements(prepared);
            if(!readiness["problem"].toString().isEmpty()){issue=readiness["problem"].toString();repair=readiness.value("repair","prepare").toString();}
        }
        QMetaObject::invokeMethod(this,[this,record,prepared,issue,repair,readiness] {
            if(cancelling_){fail({});return;}
            const auto current=library_.registration(record.adventure.id);
            if(!current || current->removed || current->revision!=record.revision || current->contentPath!=record.contentPath){
                fail("This game changed before it could open. Try again.");return;
            }
            if(!issue.isEmpty()){fail(issue,repair);return;}
            const auto start=[this,prepared,readiness](const QString& error) {
                if(cancelling_){fail({});return;}
                if(!error.isEmpty()){fail(error);return;}
                const auto current=library_.registration(prepared.adventure.id);
                if(!current || current->removed || current->contentPath!=prepared.contentPath
                        || current->adventure.adapterId!=prepared.adventure.adapterId
                        || current->integrationConfig!=prepared.integrationConfig){
                    fail("This game changed before it could open. Try again.");return;
                }
                if(!adapter_.capabilities(current->adventure).launch){
                    auto reason=adapter_.setupIssue(*current);
                    fail(reason.isEmpty()?QString("No emulator is configured for this platform."):reason);return;
                }
                // Drop the preparation lock before the existing launch lifecycle
                // takes ownership of input, checkpointing and window handoff.
                busy_=false;emit changed();
                if(!playing_) {
                    const auto warning=readiness["warning"].toString();
                    emit checked(prepared.adventure.id,{{"state",warning.isEmpty()?"ready":"review"},
                        {"detail",warning.isEmpty()?QString("Game file, emulator and listed required files are available. Game compatibility is checked when you play."):warning},
                        {"repair","prepare"},{"canPlay",true}});
                    return;
                }
                const auto result=adapter_.launch(current->adventure);
                if(!result.inProgress && !result.message.isEmpty())emit messageRequested(result.message);
            };
            if(prepared.adventure.adapterId!=current->adventure.adapterId || prepared.integrationConfig!=current->integrationConfig) {
                stage_="Applying verified launch settings…";emit changed();
                library_.saveAdventureAsync(prepared,this,[this,start](const LibraryWriteResult& result){
                    if(result.success)emit libraryChanged();
                    start(result.success?QString():result.error);
                });
            }
            else start({});
        },Qt::QueuedConnection);
    });
    worker_->start();
}
}
