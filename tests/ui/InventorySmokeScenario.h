#pragma once
#include "core/navigation/ShellController.h"
#include "../fixtures/ProfileInventoryFixture.h"
#include "../fixtures/InventoryResponseFixture.h"
#include <QQuickWindow>
#include <QQuickItem>
#include <QTimer>
#include <QMouseEvent>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <memory>
#include <functional>

inline void startInventorySmoke(QQuickWindow* window,trainer::ShellController& shell,const QString& directory,
    bool& completed,int& warnings,QStringList& diagnostics) {
    using trainer::Action;
    auto step=std::make_shared<int>(0);
    auto reply=std::make_shared<trainer::ProfileInventory::Reply>();
    auto timer=new QTimer(window);timer->setInterval(700);
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&completed,&warnings,&diagnostics]{
        const auto check=[&](bool ok,QString why){if(!ok)diagnostics.append(why);};
        const auto find=[&](QString name){
            std::function<QQuickItem*(QQuickItem*)> walk=[&](QQuickItem* item)->QQuickItem*{if(item->objectName()==name&&item->isVisible())return item;for(auto* child:item->childItems())if(auto* found=walk(child))return found;return nullptr;};
            return walk(window->contentItem());
        };
        const auto capture=[&](QString name){check(window->grabWindow().save(directory+"/"+name+".png"),"Capture "+name);};
        const auto click=[&](QString name){
            auto* item=find(name);check(item,"Touch target: "+name);if(!item)return;
            const auto point=item->mapToScene({item->width()/2,item->height()/2});const auto global=QPointF(window->mapToGlobal(point.toPoint()));
            QMouseEvent down(QEvent::MouseButtonPress,point,global,Qt::LeftButton,Qt::LeftButton,Qt::NoModifier),up(QEvent::MouseButtonRelease,point,global,Qt::LeftButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&down);QCoreApplication::sendEvent(window,&up);
        };
        const auto hover=[&](QString name){
            auto* item=find(name);check(item,"Hover target: "+name);if(!item)return;
            const auto point=item->mapToScene({item->width()/2,item->height()/2});
            QMouseEvent event(QEvent::MouseMove,point,QPointF(window->mapToGlobal(point.toPoint())),Qt::NoButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&event);
        };
        const auto respond=[&](int status,QJsonObject value){check(bool(*reply),"A private inventory request is pending");if(*reply){auto done=std::move(*reply);*reply={};done(status,std::move(value));}};
        auto* inventory=shell.inventory();
        switch((*step)++) {
        case 0:window->resize(800,450);shell.openProfile();shell.activate(12,"profile");break;
        case 1:
            check(find("inventory-empty")&&inventory->view()["items"].toList().isEmpty(),"Empty state without fake possessions");
            capture("dense-empty-800");trainer::ProfileInventoryFixture::populate(*inventory);break;
        case 2: {
            auto* grid=find("inventory-grid");check(grid,"Grid rendered");
            auto* last=find("inventory-slot-29");check(last&&grid,"Thirty slots rendered");
            if(last&&grid){auto top=last->mapToItem(grid,{0,0});check(top.y()>=0&&top.y()+last->height()<=grid->height()+1,"Thirty complete cells fit at 800x450");}
            check(find("inventory-details"),"Details visible immediately without Confirm");capture("dense-grid-800");
            shell.dispatch(Action::Right);break;
        }
        case 3:
            check(inventory->view()["selected"].toMap()["state"]=="listed","D-pad updates inspector immediately");capture("dense-listed-800");
            hover("inventory-slot-8");break;
        case 4:
            check(inventory->view()["index"].toInt()==8,"Mouse hover selects without clicking");click("inventory-slot-6");break;
        case 5:
            check(inventory->view()["index"].toInt()==6,"Touch selects without changing screen");
            inventory->activate(30);break;
        case 6:
            check(inventory->view()["index"].toInt()==30,"Stationary pointer does not steal focus while grid scrolls");
            check(find("inventory-grid")->property("contentY").toReal()>0,"Focus scrolls grid");capture("dense-scrolled-800");
            click("inventory-search");break;
        case 7:
            check(shell.keyboard()->isOpen(),"Search uses shared keyboard");shell.keyboard()->insertText("treecko");shell.keyboard()->pressKey(Qt::Key_Return);break;
        case 8:
            check(inventory->view()["items"].toList().size()==4,"Search filters immediately on acceptance");capture("dense-search-800");
            inventory->clearSearch();click("inventory-filter");click("inventory-filter");break;
        case 9:
            check(inventory->view()["items"].toList().size()==1,"On-sale filter");capture("dense-filter-800");click("inventory-filter");click("inventory-sort");break;
        case 10:
            check(inventory->view()["sort"]=="Name","Sort control");check(inventory->view()["selected"].toMap()["id"]=="sample-1","Sort preserves selected item identity");
            shell.settings()->cycleTheme();window->resize(960,540);inventory->activate(0);break;
        case 11:
            capture("dense-dark-960");shell.dispatch(Action::Secondary);break;
        case 12:
            check(shell.quickAppsOpen()&&find("quick-apps-drawer"),"X dock remains visible");shell.dispatch(Action::Back);
            shell.dispatch(Action::ToggleContinue);check(shell.drawerOpen()&&find("continue-drawer"),"Y drawer retained");shell.dispatch(Action::Back);
            shell.dispatch(Action::SystemMenu);break;
        case 13:
            check(shell.menuOpen(),"Start overlays inventory");shell.dispatch(Action::Back);shell.dispatch(Action::Back);
            check(shell.profileRoute()=="summary"&&shell.profileFocus()==12,"One Back returns to profile");
            shell.activate(12,"profile");shell.dispatch(Action::Home);break;
        case 14: {
            check(shell.primaryId()=="home"&&!shell.serviceOpen(),"Home returns");inventory->setScope("other-owner",{});
            check(inventory->view()["items"].toList().isEmpty()&&inventory->view()["search"].toString().isEmpty(),"Owner change clears items and filters");
            shell.openProfile();shell.activate(12,"profile");window->resize(800,450);shell.settings()->cycleTheme();
            // Use the real account -> shell scope -> inventory route. A direct
            // synthetic scope is correctly cleared by the shell's account owner.
            trainer::BackendAccount::Services services;
            services.read=[](QString,auto done){done(true,QJsonDocument(QJsonObject{{"refresh_token",QString(43,'r')}}).toJson());};
            services.write=[](QString,QByteArray,auto done){done(true);};
            services.readCommerce=[](QString){return QByteArray("{}");};
            services.writeCommerce=[](QString,QByteArray){return true;};
            services.request=[reply](QByteArray,QString path,QJsonObject,QByteArray,trainer::BackendAccount::Reply done){
                if(path=="/v1/auth/refresh")done(200,{{"player_id","11111111-1111-4111-8111-111111111111"},
                    {"session_id","33333333-3333-4333-8333-333333333333"},{"fluxer_subject","12345"},
                    {"access_token",QString(43,'a')},{"refresh_token",QString(43,'r')},
                    {"expires_at",QDateTime::currentDateTimeUtc().addSecs(900).toString(Qt::ISODateWithMs)}});
                else if(path.startsWith("/v1/me/loot"))*reply=std::move(done);
                else done(503,{});
            };
            auto* backend=shell.backendAccount();backend->configure({});backend->setServices(std::move(services));
            backend->configure(shell.trainer()->profile()["id"].toString());break;
        }
        case 15:
            check(inventory->view()["busy"].toBool(),"Loading is distinct from confirmed empty");capture("server-loading-800");
            respond(200,trainer::inventoryResponse("11111111-1111-4111-8111-111111111111",0,0,0));break;
        case 16:
            check(inventory->view()["state"]=="ready"&&inventory->view()["total"].toInt()==0,"Confirmed empty server inventory");capture("server-empty-800");
            click("inventory-refresh");respond(0,{});break;
        case 17:
            check(inventory->view()["state"]=="error","Failure is not an empty inventory");capture("server-error-800");
            click("inventory-refresh");respond(200,trainer::inventoryResponse("11111111-1111-4111-8111-111111111111"));break;
        case 18:
            check(inventory->view()["loaded"].toInt()==60&&inventory->view()["hasMore"].toBool(),"Generic server rows and pagination");
            click("inventory-slot-1");capture("server-equipment-800");click("inventory-more");break;
        case 19:
            check(inventory->view()["busy"].toBool(),"Touch loads next page");respond(200,trainer::inventoryResponse("11111111-1111-4111-8111-111111111111",60,1));break;
        case 20:
            check(inventory->view()["loaded"].toInt()==61&&!inventory->view()["hasMore"].toBool(),"All server items loaded once");
            shell.dispatch(Action::Up);for(int i=0;i<4;++i)shell.dispatch(Action::Right);shell.dispatch(Action::Confirm);
            check(inventory->view()["busy"].toBool(),"Controller refreshes inventory");respond(404,{});break;
        case 21:
            check(inventory->view()["state"]=="unavailable","Older server has honest unavailable state");capture("server-unavailable-800");
            inventory->close();shell.backendAccount()->configure({});break;
        default:
            check(warnings==0,"No QML warnings");timer->stop();completed=true;
            QFile file(directory+"/inventory-report.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(QJsonObject{{"success",diagnostics.isEmpty()},{"warnings",warnings},{"diagnostics",QJsonArray::fromStringList(diagnostics)}}).toJson());
            QCoreApplication::exit(diagnostics.isEmpty()?0:1);
        }
    });timer->start();
}
