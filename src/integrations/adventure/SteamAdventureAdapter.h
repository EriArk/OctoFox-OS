#pragma once
#include "AdventureAdapter.h"
#include "core/repository/LibraryRepository.h"
#include "platform/process/ProcessService.h"
#include "features/pc/PcRuntime.h"
#include <QFileInfo>
#include <QJsonDocument>

namespace trainer {
class SteamAdventureAdapter final : public AdventureAdapter {
public:
    LibraryRepository* library=nullptr;
    std::function<AdventureResult(const ProcessCommand&,const QString&)> requestLaunch;
    QString id() const override{return "steam";}
    AdventureCapabilities capabilities(const Adventure& a) const override{return {a.adapterId==id()&&!a.collectionOnly,false,true};}
    QString setupIssue(const AdventureRegistration& r) const override{return r.integrationConfig["issue"].toString();}
    QString verifyInstallation(const AdventureRegistration& r) const override {
        if(!QFileInfo("/var/opt/traineros/integrations/steam_session.py").isFile())return "Steam library support is not installed on this device.";
        if(!QFileInfo(r.contentPath).isFile())return "This Steam library is unavailable. Reconnect its storage and refresh Games.";
        if(!setupIssue(r).isEmpty())return setupIssue(r);
        return {};
    }
    AdventureResult launch(const Adventure& a) override {
        const auto r=library?library->registration(a.id):std::nullopt;
        if(!r)return {false,"This Steam game is unavailable."};
        ProcessCommand command;command.program="/usr/bin/python3";
        command.arguments={"/var/opt/traineros/integrations/steam_session.py","launch",
            QString::fromUtf8(QJsonDocument(r->integrationConfig).toJson(QJsonDocument::Compact))};
        command.runtimeControls={{"kind","steam"}};
        command.readyMarker="TRAINEROS_STEAM_READY";
        auto tail=std::make_shared<QByteArray>();
        command.inspectOutput=[tail](const QByteArray& bytes){*tail=(*tail+bytes).right(4096);return QString();};
        command.finalize=[tail](const ProcessOutcome& outcome){
            const QByteArray marker="TRAINEROS_PC_ERROR:";const auto at=tail->indexOf(marker);
            return outcome.exitCode!=0&&at>=0?QString::fromUtf8(tail->mid(at+marker.size())).trimmed().left(600):QString();
        };
        return requestLaunch?requestLaunch(command,a.id):AdventureResult{false,"Steam launch is unavailable."};
    }
    AdventureResult resume(const Adventure& a,const ResumePoint&) override{return launch(a);}
};
}
