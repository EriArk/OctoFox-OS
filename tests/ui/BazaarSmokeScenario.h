#pragma once
#include "core/navigation/ShellController.h"
#include "core/input/ControllerInput.h"
#include "../fixtures/BazaarFixture.h"
#include "../fixtures/BazaarCommerceFixture.h"
#include <QQuickWindow>
#include <QQuickItem>
#include <QTimer>
#include <QMouseEvent>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <memory>
#include <functional>
#include <QWheelEvent>

inline void startBazaarSmoke(QQuickWindow* window,trainer::ShellController& shell,trainer::ControllerInput& input,
    SDL_Joystick* joystick,const QString& directory,bool& completed,int& warnings,QStringList& diagnostics) {
    using trainer::Action;using trainer::ControllerInput;using trainer::BazaarFixture;
    auto commerce=std::make_shared<trainer::BazaarCommerceFixture>();commerce->seedStall=false;
    auto step=std::make_shared<int>(0);auto scroll=std::make_shared<qreal>(0);
    auto timer=new QTimer(window);timer->setInterval(650);
    const auto press=[&input,joystick](SDL_GameControllerButton button){SDL_JoystickSetVirtualButton(joystick,button,1);input.poll();SDL_JoystickSetVirtualButton(joystick,button,0);input.poll();};
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&completed,&warnings,&diagnostics]{
        auto* page=shell.bazaar();
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
        switch((*step)++) {
        case 0:window->resize(960,540);shell.openOnlineFace("bazaar");break;
        case 1:
            check(page->rooms().isEmpty(),"No invented player worlds");capture("catalogue-preview-960");click("bazaar-official");break;
        case 2:
            check(page->dialog()=="preview-official"&&find("bazaar-world-preview"),"Official opens fullscreen placeholder");capture("official-preview-960");
            shell.dispatch(Action::NextFace);check(shell.onlineFace()=="bazaar","Preview traps face switching");
            check(!find("quick-apps-drawer"),"Closed dock does not obscure placeholder notice");
            shell.dispatch(Action::Secondary);check(shell.quickAppsOpen()&&find("quick-apps-drawer"),"X opens visible dock over preview");shell.dispatch(Action::Back);
            shell.dispatch(Action::ToggleContinue);check(shell.drawerOpen()&&find("continue-drawer"),"Y opens visible drawer over preview");shell.dispatch(Action::Back);
            shell.dispatch(Action::SystemMenu);check(shell.menuOpen(),"Start overlays preview");shell.dispatch(Action::Back);break;
        case 3:
            check(page->dialog()=="preview-official","Start dismissal preserves preview");click("bazaar-preview-back");click("bazaar-create");break;
        case 4:
            check(page->dialog()=="preview-player","Personal preview without signing in or buying");capture("player-preview-960");window->resize(800,450);break;
        case 5:
            capture("player-preview-800");press(ControllerInput::BackButton);click("bazaar-official");break;
        case 6:
            capture("official-preview-800");shell.dispatch(Action::Home);check(page->dialog().isEmpty()&&shell.primaryId()=="home","Home dismisses placeholder");
            shell.openOnlineFace("bazaar");shell.settings()->cycleTheme();BazaarFixture::populate(*page);page->focus("official");break;
        case 7:
            capture("catalogue-dark-800");press(SDL_CONTROLLER_BUTTON_DPAD_RIGHT);check(page->selectedIndex()==0,"Right enters player grid");
            for(int i=0;i<4;++i)press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);break;
        case 8: {
            auto* grid=find("bazaar-player-grid");check(grid&&grid->property("contentY").toReal()>0,"Player cards scroll");
            *scroll=page->property("scroll").toReal();capture("catalogue-scrolled-800");press(ControllerInput::ConfirmButton);break;
        }
        case 9:
            check(page->dialog()=="preview-player","A real player card also explains the future world");capture("player-preview-dark-800");press(ControllerInput::BackButton);
            shell.openOnlineFace("chats");shell.openOnlineFace("bazaar");check(qAbs(page->property("scroll").toReal()-*scroll)<1,"Return keeps catalogue position");
            page->applySearch("Mika");break;
        case 10:
            check(page->rooms().size()==1,"Search filters player cards");page->toggleFavorite("0");page->applySearch("");page->toggleFilter();break;
        case 11:
            check(page->rooms().size()==1&&page->favoritesOnly(),"Favorites retained");page->toggleFilter();page->applySearch("");
            shell.dispatch(Action::ToggleContinue);check(shell.drawerOpen(),"Global Y preserved");shell.dispatch(Action::Back);
            shell.dispatch(Action::Secondary);check(shell.quickAppsOpen(),"Global X preserved");shell.dispatch(Action::Back);break;
        case 12: {
            auto services=commerce->services();services.bazaarDevelopmentPayments=false;
            auto* backend=shell.backendAccount();backend->configure({});backend->setServices(services);backend->configure("bazaar-preview-test");
            BazaarFixture::useProvider(*page);page->refresh();page->activate("create");break;
        }
        case 13:
            check(page->dialog()=="preview-player","Signed-in players still see placeholder");
            shell.backendAccount()->reviewBazaarPurchase();shell.backendAccount()->reviewBazaarPurchase(true);shell.backendAccount()->confirmPurchase();
            shell.backendAccount()->rentBazaarPlace({{"id",commerce->stall},{"revision","1"},{"weekly_price",100},{"rentable",true}},commerce->place);
            check(commerce->charges==0&&commerce->stallCharges==0&&commerce->rentCharges==0,"No Bazaar Sparks spending through old offers or direct actions");
            check(!page->account()["paymentsAvailable"].toBool(),"Payments closed by default");
            capture("player-preview-signed-in-800");shell.dispatch(Action::Home);break;
        default:
            check(warnings==0,"No QML warnings");timer->stop();completed=true;
            QFile file(directory+"/bazaar-report.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(QJsonObject{{"success",diagnostics.isEmpty()},{"warnings",warnings},{"diagnostics",QJsonArray::fromStringList(diagnostics)}}).toJson());
            QCoreApplication::exit(diagnostics.isEmpty()?0:1);
        }
    });timer->start();
}
