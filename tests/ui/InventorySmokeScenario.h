#pragma once
#include "core/navigation/ShellController.h"
#include "../fixtures/ProfileInventoryFixture.h"
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
        auto* inventory=shell.inventory();
        switch((*step)++) {
        case 0:window->resize(960,540);shell.openProfile();break;
        case 1:
            capture("profile-entry-960");click("profile-inventory");break;
        case 2:
            check(shell.profileRoute()=="inventory"&&find("inventory-empty"),"Free profile entry without a bazaar or sign-in");
            check(inventory->view()["items"].toList().isEmpty(),"No sample possessions in production");
            capture("inventory-empty-960");window->resize(800,450);break;
        case 3:
            capture("inventory-empty-800");trainer::ProfileInventoryFixture::populate(*inventory);window->resize(960,540);break;
        case 4:
            check(find("inventory-item-0"),"Fixture grid is rendered");capture("inventory-grid-960");click("inventory-item-0");break;
        case 5:
            check(inventory->view()["detail"].toBool(),"Touch opens full item details");capture("inventory-detail-960");window->resize(800,450);break;
        case 6:
            capture("inventory-detail-800");shell.dispatch(Action::Down);shell.dispatch(Action::Back);shell.dispatch(Action::Down);shell.dispatch(Action::Down);break;
        case 7:
            check(inventory->view()["index"].toInt()==6,"Controller moves through three-column grid");
            check(find("inventory-grid")&&find("inventory-grid")->property("contentY").toReal()>0,"Grid scrolls with focus");
            capture("inventory-grid-scrolled-800");shell.dispatch(Action::Confirm);shell.dispatch(Action::Secondary);break;
        case 8:
            check(shell.quickAppsOpen()&&find("quick-apps-drawer"),"Global X opens a visible dock over inventory");capture("inventory-dock-800");shell.dispatch(Action::Back);
            shell.dispatch(Action::ToggleContinue);check(shell.drawerOpen()&&find("continue-drawer"),"Global Y opens a visible drawer over inventory");shell.dispatch(Action::Back);
            check(inventory->view()["detail"].toBool(),"Closing dock preserves item");shell.dispatch(Action::Back);shell.dispatch(Action::Back);break;
        case 9:
            check(shell.profileRoute()=="summary"&&shell.profileFocus()==12,"Back restores profile entry focus");
            shell.settings()->cycleTheme();click("profile-inventory");inventory->activate(1);break;
        case 10:
            check(inventory->view()["selected"].toMap()["state"]=="listed","Listing presentation retained");
            capture("inventory-listed-dark-800");shell.dispatch(Action::SystemMenu);break;
        case 11:
            check(shell.menuOpen(),"Start opens over inventory");shell.dispatch(Action::Back);
            check(shell.profileRoute()=="inventory","Start dismissal retains inventory");shell.dispatch(Action::Home);break;
        case 12:
            check(shell.primaryId()=="home"&&!shell.serviceOpen(),"Home leaves profile");
            inventory->setScope("another-owner",{});shell.openProfile();shell.activate(12,"profile");break;
        case 13:
            check(inventory->view()["items"].toList().isEmpty()&&!inventory->view()["detail"].toBool(),"Owner change clears old records and detail");
            capture("inventory-empty-dark-800");break;
        default:
            check(warnings==0,"No QML warnings");timer->stop();completed=true;
            QFile file(directory+"/inventory-report.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(QJsonObject{{"success",diagnostics.isEmpty()},{"warnings",warnings},{"diagnostics",QJsonArray::fromStringList(diagnostics)}}).toJson());
            QCoreApplication::exit(diagnostics.isEmpty()?0:1);
        }
    });timer->start();
}
