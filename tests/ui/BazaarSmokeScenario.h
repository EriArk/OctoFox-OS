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
    auto commerce=std::make_shared<trainer::BazaarCommerceFixture>();
    auto step=std::make_shared<int>(0);auto scroll=std::make_shared<qreal>(0);auto officialY=std::make_shared<qreal>(0);
    auto snapshot=std::make_shared<QJsonObject>();
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
            check(page->rooms().isEmpty(),"Production has no fabricated player rooms");capture("empty-light");click("bazaar-official");break;
        case 2:
            check(page->dialog()=="realms"&&page->realms().isEmpty(),"Official Enter opens unavailable realm picker");capture("realms-empty");
            shell.dispatch(Action::NextFace);check(shell.onlineFace()=="bazaar","Realm dialog traps face switching");click("bazaar-dialog-close");click("bazaar-create");break;
        case 3:
            check(page->dialog()=="purchase","Unpurchased bazaar offers purchase first");capture("create-unavailable");press(ControllerInput::BackButton);BazaarFixture::populate(*page);page->focus("official");break;
        case 4: {
            capture("catalogue-light");auto* card=find("bazaar-official");check(card,"Official card visible");if(card)*officialY=card->y();
            press(SDL_CONTROLLER_BUTTON_DPAD_RIGHT);check(page->selectedIndex()==0,"SDL Right enters grid");
            for(int i=0;i<4;++i)press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);
            check(page->selectedIndex()==8,"SDL traverses two columns");break;
        }
        case 5: {
            auto* grid=find("bazaar-player-grid");check(grid&&grid->property("contentY").toReal()>0,"Focus scrolls player grid");
            auto* card=find("bazaar-official");check(card&&card->y()==*officialY,"Official card stays fixed");
            *scroll=page->property("scroll").toReal();capture("catalogue-scrolled");shell.openOnlineFace("chats");shell.openOnlineFace("bazaar");break;
        }
        case 6:check(page->selection()=="room:8"&&qAbs(page->property("scroll").toReal()-*scroll)<1,"Face return retains ID and scroll");window->resize(800,450);break;
        case 7:capture("catalogue-light-800");shell.settings()->cycleTheme();break;
        case 8:capture("catalogue-dark-800");click("bazaar-official");break;
        case 9:
            check(page->dialog()=="realms"&&page->realms().size()==3,"Enter reaches test realms");capture("realms-dark-800");
            click("bazaar-realm-2");check(shell.notice().isEmpty(),"Full realm cannot join");press(ControllerInput::BackButton);click("bazaar-search");break;
        case 10:
            check(shell.keyboard()->isOpen(),"Touch search uses shared keyboard");shell.dispatch(Action::Back);page->applySearch("Mika");break;
        case 11:
            check(page->rooms().size()==1,"Search filters player cards only");check(find("bazaar-official"),"Search leaves official card");
            page->toggleFavorite("0");page->applySearch("");click("bazaar-filter");break;
        case 12:
            check(page->favoritesOnly()&&page->rooms().size()==1,"Favorites filter");capture("favorites-dark-800");click("bazaar-filter");
            page->applySearch("missing");break;
        case 13:
            check(page->rooms().isEmpty(),"No-match state");capture("no-matches-dark-800");page->applySearch("");
            BazaarFixture::clear(*page,"Could not refresh bazaars. Try again later.");window->resize(960,540);break;
        case 14:
            capture("directory-error");page->activate("official");shell.dispatch(Action::Home);check(page->dialog().isEmpty()&&shell.primaryId()=="home","Home closes dialog and returns Home");
            shell.openOnlineFace("bazaar");shell.dispatch(Action::ToggleContinue);check(shell.drawerOpen(),"Global Y retains Recents");shell.dispatch(Action::Back);break;
        case 15:
            shell.dispatch(Action::Secondary);check(shell.quickAppsOpen(),"Global X retains Quick Apps");shell.dispatch(Action::Back);
            shell.dispatch(Action::NextFace);check(shell.onlineFace()=="chats","R2 leaves catalogue");
            shell.dispatch(Action::PreviousFace);check(shell.onlineFace()=="bazaar","L2 returns to catalogue");
            BazaarFixture::populate(*page);page->focus("official");page->applySearch("");break;
        case 16: {
            auto* grid=find("bazaar-player-grid");check(grid,"Wheel grid target");if(!grid)break;
            const auto point=grid->mapToScene({grid->width()/2,grid->height()/2});
            QWheelEvent wheel(point,QPointF(window->mapToGlobal(point.toPoint())),QPoint(),QPoint(0,-360),Qt::NoButton,Qt::NoModifier,Qt::NoScrollPhase,false);
            QCoreApplication::sendEvent(window,&wheel);break;
        }
        case 17: {
            auto* grid=find("bazaar-player-grid");check(grid&&grid->property("contentY").toReal()>0,"Pointer wheel scrolls grid");
            *scroll=page->property("scroll").toReal();check(*scroll>0,"Pointer scroll is saved");
            capture("catalogue-dark");*snapshot=shell.navigationState();shell.goToPage(0);shell.restoreNavigation(*snapshot);break;
        }
        case 18:
            check(shell.onlineFace()=="bazaar"&&qAbs(page->property("scroll").toReal()-*scroll)<1,"Navigation snapshot restores pointer scroll");
            page->activate("official");shell.dispatch(Action::SystemMenu);check(shell.menuOpen(),"Start overlays realm picker");
            shell.dispatch(Action::Back);check(page->dialog()=="realms","System panel preserves realm picker");
            shell.dispatch(Action::Back);check(page->dialog().isEmpty(),"Back closes preserved realm picker");break;
        case 19:
            commerce->install(*shell.backendAccount());BazaarFixture::useProvider(*page);page->refresh();page->activate("create");break;
        case 20:
            check(page->dialog()=="purchase","Purchase precedes settings");capture("purchase-dark-960");page->dialogAction("review");break;
        case 21:
            check(page->dialog()=="review"&&commerce->charges==0,"Price review is not a purchase");capture("purchase-review-dark-960");press(ControllerInput::ConfirmButton);break;
        case 22:
            check(commerce->charges==1&&page->dialog()=="ready"&&page->account()["owned"].toMap().isEmpty(),"Purchase unlocks right without creating space");
            capture("purchased-later-dark-960");page->dialogAction("back");shell.dispatch(Action::Home);break;
        case 23:
            shell.openOnlineFace("bazaar");page->activate("create");check(page->dialog()=="ready","Returning retains purchased right");page->dialogAction("setup");break;
        case 24:
            check(page->dialog()=="create","Create when ready opens settings");capture("create-free-dark-960");click("bazaar-action-name");break;
        case 25:
            check(shell.keyboard()->isOpen(),"Name uses shared keyboard");shell.keyboard()->insertText("Nym Market");shell.keyboard()->pressKey(Qt::Key_Return);
            check(!shell.keyboard()->isOpen(),"Name edit accepted");page->dialogAction("create");break;
        case 26:
            check(commerce->charges==1&&page->dialog()=="manage","Creation reaches My bazaar without second payment");capture("manage-dark-960");
            page->dialogAction("listed");page->dialogAction("access");page->dialogAction("save");break;
        case 27:
            check(commerce->edits==1&&commerce->charges==1,"Owner settings save without a second charge");
            check(!page->account()["owned"].toMap()["listed"].toBool(),"Hidden setting persisted");
            window->resize(800,450);shell.settings()->cycleTheme();break;
        case 28:
            capture("manage-light-800");commerce->conflict=true;page->dialogAction("listed");page->dialogAction("save");break;
        case 29:
            check(page->message().contains("another device"),"Edit conflict keeps draft");capture("manage-conflict-light-800");
            shell.dispatch(Action::Home);check(page->dialog().isEmpty()&&shell.primaryId()=="home","Home dismisses owner form");break;
        default:
            check(warnings==0,"No QML warnings");timer->stop();completed=true;
            QFile file(directory+"/bazaar-report.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(QJsonObject{{"success",diagnostics.isEmpty()},{"warnings",warnings},{"diagnostics",QJsonArray::fromStringList(diagnostics)}}).toJson());
            QCoreApplication::exit(diagnostics.isEmpty()?0:1);
        }
    });timer->start();
}
