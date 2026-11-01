#include "SteamLibrary.h"
#include <QFileInfo>
#include <QJsonDocument>
#include <QRegularExpression>

namespace trainer {
SteamLibrary::SteamLibrary(LibraryRepository& library,QObject* parent):QObject(parent),library_(library) {
    deadline_.setSingleShot(true);deadline_.setInterval(30000);
    connect(&deadline_,&QTimer::timeout,&process_,&QProcess::kill);
    connect(&process_,&QProcess::readyReadStandardOutput,this,[this]{
        output_+=process_.readAllStandardOutput();if(output_.size()>8*1024*1024)process_.kill();
    });
    connect(&process_,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){
        if(e==QProcess::FailedToStart){deadline_.stop();busy_=false;emit changed();}
    });
    connect(&process_,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
        deadline_.stop();output_+=process_.readAllStandardOutput();
        const auto document=QJsonDocument::fromJson(output_);output_.clear();
        if(code||status!=QProcess::NormalExit||!document.isObject()||!document.object()["games"].isArray()) {
            busy_=false;emit notice("Steam discovery could not finish. Your existing games and history were kept.");emit changed();return;
        }
        const auto warnings=document.object()["warnings"].toArray();
        const auto warning=warnings.isEmpty()?QString():warnings.first().toString();
        if(!warning.isEmpty()&&warning!=lastWarning_)emit notice(warning);
        lastWarning_=warning;busy_=false;reconcile(document.object()["games"].toArray());
    });
}
SteamLibrary::~SteamLibrary(){process_.disconnect(this);process_.kill();process_.waitForFinished(1000);}
void SteamLibrary::scan(){
    if(busy_||!library_.editable()||!QFileInfo("/var/opt/traineros/integrations/steam_library.py").isFile())return;
    busy_=true;output_.clear();deadline_.start();
    process_.setStandardErrorFile(QProcess::nullDevice());
    process_.start("/usr/bin/python3",{"/var/opt/traineros/integrations/steam_library.py","scan"});
}
void SteamLibrary::reconcile(const QJsonArray& games){
    if(busy_)return;if(canApply&&!canApply()){emit changed();return;}games_=games;index_=0;busy_=true;next();
}
void SteamLibrary::next(){
    while(index_<games_.size()) {
        auto config=games_[index_++].toObject();const auto app=config["appId"].toString();
        if(!QRegularExpression("^[1-9][0-9]{0,9}$").match(app).hasMatch())continue;
        const auto path=config["manifest"].toString();const auto title=config.take("title").toString().trimmed().left(96);
        if(title.isEmpty()||!QFileInfo(path).isAbsolute()||QFileInfo(path).fileName()!=QString("appmanifest_%1.acf").arg(app))continue;
        config.remove("manifest");
        const QString id="steam:"+app;const auto previous=library_.registration(id);
        if(previous&&(previous->removed||previous->adventure.adapterId!="steam"))continue;
        if(previous&&previous->integrationConfig==config&&previous->contentPath==path)continue;
        auto record=previous.value_or(AdventureRegistration{});
        record.adventure.id=id;record.adventure.adapterId="steam";record.adventure.platformId="steam";record.adventure.domain="multiverse";
        if(!previous)record.adventure.title=title; // Keep deliberate personal renames.
        record.contentPath=path;record.integrationConfig=config;
        library_.saveAdventureAsync(record,this,[this](LibraryWriteResult result){
            if(!result.success){busy_=false;games_={};emit notice(result.error);emit changed();return;}
            QTimer::singleShot(0,this,&SteamLibrary::next);
        });return;
    }
    busy_=false;games_={};emit changed();
}
}
