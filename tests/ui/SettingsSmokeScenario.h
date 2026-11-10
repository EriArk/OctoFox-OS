#pragma once
#include "core/navigation/ShellController.h"
#include "core/input/ControllerInput.h"
#include "../fixtures/HomeSocialFixture.h"
#include <QQuickWindow>
#include <QQuickItem>
#include <QtTest/QTest>
#include <QTimer>
#include <QGuiApplication>
#include <QImage>
#include <QTemporaryDir>
#include <QSettings>
#include <QDir>
#include <memory>
#include <functional>
#include <QJsonArray>
class SettingsNetworkFixture final : public trainer::NetworkService {
public:
    using NetworkService::NetworkService;
    QJsonArray rows{
        QJsonObject{{"id","saved:home"},{"title","Home network"},{"detail","Connected · 92%"},{"address","192.0.2.8"},{"connected",true},{"saved",true},{"available",true},{"security","wpa-psk"},{"autoconnect",true}},
        QJsonObject{{"id","saved:guest"},{"title","Guest network"},{"detail","Saved · 74%"},{"connected",false},{"saved",true},{"available",true},{"security","wpa-psk"}},
        QJsonObject{{"id","ap:cafe"},{"title","Cafe Wi-Fi"},{"detail","Open network · 56%"},{"connected",false},{"saved",false},{"available",true},{"security","open"}}
    };
    void request(const QJsonObject& value) override {
        QTimer::singleShot(20,this,[this,value]{
            emit event({{"event","snapshot"},{"rows",rows}});
            emit finished(value["op"]=="connect"?"Wi-Fi authentication failed. The password may be incorrect. Re-enter it and try again.":QString());
        });
    }
    void cancel() override {emit finished("Cancelled");}
};
class SettingsInputLibrary final : public trainer::LibraryRepository {
public:
    QList<trainer::World> worlds() const override{return {};}
    QList<trainer::Adventure> adventures() const override {
        trainer::Adventure a;a.id="pc:input-preview";a.title="My PC game";a.platformId="pc";a.adapterId="pc-local";return {a};
    }
    QList<trainer::ResumePoint> resumePoints() const override{return {};}
    trainer::HomeSnapshot home() const override{return {};}
};
inline void startSettingsSmoke(QQuickWindow* window, trainer::ShellController& shell,
    trainer::ControllerInput& input,const QString& directory,bool& completed,int& warnings,QStringList& diagnostics) {
    auto folder=std::make_shared<QTemporaryDir>();auto library=std::make_shared<SettingsInputLibrary>();
    auto network=new SettingsNetworkFixture(window);
    QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,folder->path());
    auto step=std::make_shared<int>(0);auto timer=new QTimer(window);timer->setInterval(450);
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&input,&completed,&warnings,&diagnostics]{
        auto* settings=shell.settings();auto* flow=settings->gameInput();
        const auto capture=[&](QString name){if(!directory.isEmpty()&&!window->grabWindow().save(QDir(directory).filePath(name+".png")))diagnostics<<"Settings capture failed: "+name;};
        const auto check=[&](bool ok,QString why){if(!ok)diagnostics<<why;};
        std::function<QQuickItem*(QQuickItem*,const QString&)> visibleItem = [&](QQuickItem* item,const QString& name)->QQuickItem* {
            if(!item || !item->isVisible())return nullptr;
            if(item->objectName()==name)return item;
            for(auto* child:item->childItems())if(auto* found=visibleItem(child,name))return found;
            return nullptr;
        };
        const auto diagram=[&](const QString& name){
            auto* item=window->findChild<QQuickItem*>(name);
            check(item&&item->isVisible()&&item->width()>=150&&item->height()>=140,"Usable diagram area: "+name);
            if(item)check(item->parentItem()->boundingRect().contains(item->mapRectToItem(item->parentItem(),item->boundingRect())),"Diagram stays in its pane: "+name);
        };
        const auto tap=[&](QQuickItem* item){
            check(item&&item->isVisible(),"Touch target is visible");
            if(item)QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,item->mapToScene(item->boundingRect().center()).toPoint());
        };
        // A light/dark sweep of every Settings page at the handheld viewport.
        static const QStringList pages{"appearance","audio","media","feedback","trainer","system","credits","controller","library","saves","connections","clock","nearby","communication","scraper","software","game-input","online-services"};
        if(*step>=48 && *step<86) {
            const int n=*step-48;
            if(n==0){window->resize(960,540);settings->selectPage(pages[0],true);}
            else if(n<=36){
                const int previous=n-1;
                capture("audit-"+QString(previous<18?"light-":"dark-")+pages[previous%18]);
                if(n==18)settings->cycleTheme(1);
                if(n<36)settings->selectPage(pages[n%18],true);
                else {window->resize(1920,1080);settings->selectPage("system",true);}
            } else capture("audit-dark-system-1080");
            ++*step;return;
        }
        switch((*step)++) {
        case 0: window->resize(960,540);shell.systemAction("settings");break;
        case 1: check(shell.service()=="settings","Settings opens from system actions");capture("settings-appearance");
            settings->selectPage("controller"); {auto p=input.profile();p["family"]="playstation";input.setProfile(p);} break;
        case 2: {
            capture("settings-controller-960");diagram("settings-controller-diagram");check(input.glyph("A")==QString::fromUtf8("×"),"Controller glyphs follow profile");
            // Touch the visible stepper, not its C++ action. It must not also
            // activate the underlying row and accidentally advance two families.
            auto* row=visibleItem(window->contentItem(),"settings-control-1");
            tap(visibleItem(row,"settings-step-next"));
            check(input.family()=="steam","One stepper tap changes one family");
            auto p=input.profile();p["family"]="playstation";input.setProfile(p);
            shell.dispatch(trainer::Action::NextFace);check(settings->categoryId()=="game-input","Shell routes triggers to Settings pages");
            flow->configure(library.get(),folder->path(),"preview-owner");break;
        }
        case 3: capture("settings-game-picker");flow->dispatch(trainer::Action::Confirm);flow->activate(0);break;
        case 4: {
            auto* grid=window->findChild<QQuickItem*>("settings-input-grid");
            auto* detail=visibleItem(window->contentItem(),"settings-input-detail-0");
            check(grid&&grid->property("columns").toInt()==2,"Setup has two compact columns");
            check(detail&&detail->isVisible()&&detail->property("text").toString()=="Keyboard & mouse","Current input mode is visible");
            capture("settings-game-setup");shell.dispatch(trainer::Action::NextFace);check(flow->page()==1,"Shell routes triggers to editor tabs");flow->selectBinding("south");break;
        }
        case 5: {
            auto* grid=window->findChild<QQuickItem*>("settings-input-grid");
            check(grid&&grid->property("columns").toInt()==4,"Action palette uses a grid");
            capture("settings-assignment");flow->dispatch(trainer::Action::Back);break;
        }
        case 6: capture("settings-buttons");flow->setPage(2);flow->activate(flow->rows().size()-5);break;
        case 7: capture("settings-ring-960");diagram("settings-ring-diagram");flow->activate(23);flow->setTargetGroup(2);flow->dispatch(trainer::Action::Confirm);
            check(flow->draft()["rings"].toList()[0].toList()[0].toString()=="A","Ring edited through action palette");
            window->resize(1280,720);break;
        case 8: capture("settings-ring-1280");flow->activate(flow->rows().size()-2);check(flow->status().startsWith("Saved"),"Game profile saved");window->resize(960,540);settings->selectPage("audio");break;
        case 9: capture("settings-audio");settings->selectPage("communication");break;
        case 10: capture("settings-communication");settings->clock()->read=[] {return trainer::ClockSnapshot{"Asia/Jerusalem",{}, {"Asia/Jerusalem","Asia/Tokyo"},true,true,true,true};};settings->selectPage("clock");break;
        case 11: capture("settings-clock");settings->selectPage("system");break;
        case 12: capture("settings-system");settings->selectPage("appearance");settings->cycleTheme(1);break;
        case 13: check(settings->theme()=="dark","Dark mode selected");capture("settings-dark");settings->selectPage("controller",true);settings->activateRow(0);break;
        case 14: check(input.captureMode()=="center","Calibration owns controller input");capture("settings-calibration-dark");input.cancelCapture();settings->selectPage("game-input",true);flow->setPage(1);flow->openTools();break;
        case 15: capture("settings-input-tools-dark");flow->activateTool(1);break;
        case 16: capture("settings-input-capture-dark");QTest::keyClick(window,Qt::Key_K,Qt::ControlModifier|Qt::AltModifier);break;
        case 17: check(input.captureMode().isEmpty()&&!flow->choosing(),"Captured key returns to editor");flow->setPage(2);flow->editRingName(0);shell.keyboard()->cancel();flow->applyText("Quick actions");flow->cycleRingIcon(0,0);flow->previewRing(0);break;
        case 18: capture("settings-ring-preview-dark");flow->back();settings->selectPage("appearance",false);settings->dispatch(trainer::Action::Back);shell.goToPage(0);break;
        case 19: capture("home-dark");shell.goToPage(1);break;
        case 20: capture("games-dark");shell.goToPage(3);break;
        case 21: capture("social-dark");shell.goToPage(4);break;
        case 22: capture("apps-dark");settings->cycleTheme(1);break;
        case 23: {
            capture("settings-system");
            trainer::BackendAccount::Services services;
            services.read=[](QString,auto done){done(true,{});};
            services.write=[](QString,QByteArray,auto done){done(true);};
            services.openBrowser=[](QUrl){return true;};
            services.request=[](QByteArray,QString path,QJsonObject,QByteArray,auto done){
                if(path=="/v1/auth/login-attempts")done(201,{{"attempt_id","22222222-2222-4222-8222-222222222222"},
                    {"authorization_url","https://traineros-api.abysstail.art/v1/auth/fluxer/start"}});
                else done(500,{});
            };
            shell.backendAccount()->setServices(std::move(services));shell.backendAccount()->configure("settings-account-fixture");
            shell.systemAction("settings");settings->selectPage("trainer");break;
        }
        case 24:
            for(int i=0;i<5;++i)shell.dispatch(trainer::Action::Down);
            check(settings->rowFocus()==5,"Controller reaches TrainerOS account action");break;
        case 25:
            capture("settings-account");tap(visibleItem(window->contentItem(),"settings-control-5"));
            check(shell.backendAccount()->actionLabel().startsWith("Cancel"),"Touch begins browser sign-in");break;
        case 26:
            capture("settings-account-waiting");shell.dispatch(trainer::Action::Confirm);
            check(shell.backendAccount()->detail().contains("cancelled"),"Controller cancels browser sign-in");
            shell.backendAccount()->configure({});break;
        case 27: shell.network()->configure(network);settings->selectPage("connections",true);break;
        case 28: capture("wifi-networks-960");shell.network()->activate(1);break;
        case 29: check(shell.network()->failed()&&shell.network()->detailsOpen(),"Failed Wi-Fi opens persistent error with retry");capture("wifi-password-error-960");shell.network()->activateDetail("password");break;
        case 30: check(shell.keyboard()->isOpen(),"Retry opens shared password keyboard");capture("wifi-password-keyboard");shell.dispatch(trainer::Action::Back);shell.network()->back();shell.network()->showDetails(0);break;
        case 31: check(shell.network()->detailsOpen(),"Connected network details open after cancelling password");capture("wifi-connected-960");settings->cycleTheme(1);break;
        case 32: capture("wifi-connected-dark");shell.network()->back();shell.network()->otherNetwork();shell.dispatch(trainer::Action::Back);shell.network()->otherNetwork();shell.network()->applyText("Hidden home");shell.keyboard()->cancel();break;
        case 33: capture("wifi-hidden-dark");shell.network()->back();shell.goToSection("home");break;
        case 34: tap(visibleItem(window->contentItem(),"notification-bell"));break;
        case 35: check(shell.notificationsOpen(),"Header bell opens popover by touch");check(!visibleItem(window->contentItem(),"shell-home-menu"),"Bell does not show Home menu");capture("notifications-dark-960");shell.dispatch(trainer::Action::Back);settings->cycleTheme(1);window->resize(1280,720);break;
        case 36: shell.openNotifications();break;
        case 37: capture("notifications-light-1280");shell.closeHomeMenu();shell.dispatch(trainer::Action::Home);break;
        case 38: check(!shell.homeMenuOpen()&&!shell.notificationsOpen(),"Home returns directly without a menu");capture("home-menu-no-inbox");shell.closeHomeMenu();break;
        case 39: {
            trainer::HomeSocialFixture::isolateProvider(*shell.social());
            QVariantList chats;for(int i=0;i<8;++i)chats.append(QVariantMap{{"id",QString::number(5000+i)},{"name","Player "+QString::number(i+1)},{"kind","chats"},{"unread",1},{"last","123"}});
            trainer::HomeSocialFixture::publish(*shell.social(),{{"state","connected"},{"userId","fixture"},{"chats",chats}});shell.openNotifications();break;
        }
        case 40: {
            check(shell.notifications().size()>=8,"Popover has a scrollable inbox");
            auto* popup=visibleItem(window->contentItem(),"notification-popover");auto* game=visibleItem(window->contentItem(),"home-game-card");
            check(popup&&game&&popup->mapToScene(QPointF(0,0)).x()>=0&&popup->mapToScene(QPointF(popup->width(),0)).x()<=window->width(),"Popover stays inside the window");
            capture("notifications-many-1280");shell.dismissNotifications();break;
        }
        case 41: check(shell.notifications().isEmpty(),"Clear updates empties ordinary messages");shell.closeHomeMenu();break;
        case 42: window->resize(960,540);shell.systemAction("settings");settings->configureNintendoOnline(folder->path());settings->selectPage("online-services",true);break;
        case 43: check(settings->controls().size()==5,"Nintendo services use the common Settings controls");capture("online-services-off-960");tap(visibleItem(window->contentItem(),"settings-control-1"));break;
        case 44: check(settings->controls()[1].toMap()["detail"]=="wiimmfi","Touch selects Wii service");settings->activateRow(4);break;
        case 45: check(settings->onlineServiceStatus().contains("Install the native emulator"),"Missing native setup is explained");capture("online-services-missing-960");settings->activateRow(0);settings->activateRow(1);break;
        case 46: check(settings->controls()[0].toMap()["detail"]=="Nintendo 3DS","Next family retains its own selection");check(settings->controls()[1].toMap()["detail"]=="pretendo","3DS offers Pretendo");settings->activateRow(3);settings->dispatch(trainer::Action::Back);check(!settings->controlsFocused(),"Back returns to Settings navigation");settings->selectPage("online-services",true);settings->activateRow(0);settings->activateRow(1);break;
        case 47: check(settings->controls()[0].toMap()["detail"]=="Wii U","Wii U has independent preparation");check(settings->controls()[3].toMap()["detail"].toString().startsWith("No"),"3DS confirmation does not enable Wii U");capture("online-services-wiiu-960");break;
        default:timer->stop();completed=true;qInfo()<<"Settings UI checks"<<diagnostics<<"warnings"<<warnings;QCoreApplication::exit(diagnostics.isEmpty()&&warnings==0?0:1);break;
        }
    });timer->start();
}
