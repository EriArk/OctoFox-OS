#pragma once
#include "DownloadsSmokeScenario.h"
#include "../fixtures/adapters/CounterExperience.h"
#include <QCoreApplication>
#include <QTimer>
#include <QImage>
#include <QFile>
#include <QMouseEvent>
inline void startExperienceSmoke(QQuickWindow* window,trainer::ShellController& shell,trainer::ControllerInput& input,
        SDL_Joystick* joystick,const QString& directory,bool& completed,int& warnings,QStringList& diagnostics) {
    auto timer=new QTimer(window);timer->setInterval(400);
    auto stage=std::make_shared<int>(0);auto artWaits=std::make_shared<int>(0);auto failed=std::make_shared<bool>(false);
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&input,&completed,&warnings,&diagnostics]{
        const auto check=[&](bool ok,QString message){if(!ok){*failed=true;diagnostics<<message;}};
        auto* rpg=static_cast<trainer::test::CounterExperience*>(shell.module("rpg"));
        auto* racing=static_cast<trainer::test::CounterExperience*>(shell.module("racing"));
        const auto select=[&](QString game){auto state=shell.navigationState();state["homeAdventure"]=game;state["page"]="home";shell.restoreNavigation(state);};
        const auto body=[&]{auto* item=window->findChild<QObject*>("fixture-body");return item?item->property("text").toString():QString();};
        const auto labels=[&]{QStringList result;if(auto* row=window->findChild<QQuickItem*>("shell-button-hints"))for(auto* item:row->childItems())if(item->isVisible() && item->property("label").isValid())result<<item->property("label").toString();return result;};
        const auto press=[&](SDL_GameControllerButton button){SDL_JoystickSetVirtualButton(joystick,button,1);input.poll();SDL_JoystickSetVirtualButton(joystick,button,0);input.poll();};
        const auto find=[&](QString name) {
            QList<QQuickItem*> pending{window->contentItem()};
            while(!pending.isEmpty()){auto* item=pending.takeLast();if(item->objectName()==name && item->isVisible())return item;pending.append(item->childItems());}
            return static_cast<QQuickItem*>(nullptr);
        };
        const auto click=[&](QString name){
            auto* item=find(name);check(item,"Pointer target: "+name);if(!item)return;
            const auto point=item->mapToScene({item->width()/2,item->height()/2});const auto global=QPointF(window->mapToGlobal(point.toPoint()));
            QMouseEvent down(QEvent::MouseButtonPress,point,global,Qt::LeftButton,Qt::LeftButton,Qt::NoModifier),up(QEvent::MouseButtonRelease,point,global,Qt::LeftButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&down);QCoreApplication::sendEvent(window,&up);
        };
        switch((*stage)++) {
        case 0:select(rpg->matchGame);break;
        case 1:check(body().startsWith("rpg-home"),"Independent RPG presenter not mounted");shell.openGameHubFace("adapter");shell.selectAdapterScreen("counter");break;
        case 2:press(SDL_CONTROLLER_BUTTON_B);break;
        case 3:check(rpg->count==1,"Controller did not reach registered module");check(body().endsWith("1"),"Presenter did not observe module progress");select(racing->matchGame);break;
        case 4:check(body().startsWith("racing-home"),"Second presenter did not replace Home");shell.openGameHubFace("adapter");shell.selectAdapterScreen("counter");shell.activate(9,"fixture");break;
        case 5:check(body().endsWith("9"),"Touch dispatcher did not reach registered module");select(rpg->matchGame);break;
        case 6:check(body().endsWith("1"),"Module state did not survive game switch");
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/independent-module.png"),"Empty fixture capture");
            rpg->setEnabled(false);break;
        case 7:check(shell.homeView()=="pokemon-home","Disabled module did not fall back to the next compatible presenter");shell.goToTrainerFace("ra");break;
        case 8:shell.goToPage(0);break;
        case 9:check(labels().contains("Game actions") && !labels().contains("Refresh"),"Previous adapter face leaked hints into Home");shell.goToSection("social");break;
        case 10:{QStringList expected;
            if(shell.chatNavigationFocused())expected={"Sections","Open","Home"};
            else for(const auto& hint:shell.social()->hints())if(hint.toMap()["button"]!="X" && hint.toMap()["button"]!="Y")expected<<hint.toMap()["label"].toString();
            expected<<"Home"<<"System";check(labels()==expected,"Hidden adapter leaked hints into Social: " + labels().join(" / "));break;}
        case 11:shell.openGameHubFace("overview");break;
        case 12:
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/gamehub-overview.png"),"Overview capture");
            shell.openGameHubFace("adapter");shell.showAdapterMenu();break;
        case 13:
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/gamehub-adapter-menu.png"),"Adapter menu capture");
            shell.selectAdapterScreen("party");break;
        case 14:
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/gamehub-party.png"),"Expanded adapter capture");
            window->resize(1280,800);shell.openGameHubFace("overview");break;
        case 15:
            {
                auto* view=window->findChild<QQuickItem*>("viewport");
                const auto mapped=view->mapRectToScene(view->boundingRect());
                check(qAbs(mapped.width()-1280)<1 && qAbs(mapped.height()-800)<1,"Density viewport did not fill native output");
                check(qAbs(view->width()/view->height()-1.6)<.001,"16:10 geometry did not reflow");
            }
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/gamehub-1280x800.png"),"Responsive capture");
            shell.openGameHubFace("lobby");break;
        case 16:
            check(shell.socialSurface()=="lobby","Lobby is not mounted in GameHub");
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/gamehub-lobby.png"),"Lobby capture");
            shell.goToSection("apps");shell.toggleQuickApps();break;
        case 17:
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/quick-apps.png"),"Global dock capture");
            shell.dispatch(trainer::Action::Back);break;
        case 18:
            shell.goToSection("home");window->resize(1920,1080);
            shell.dispatch(trainer::Action::SystemMenu);shell.activate(0);
            shell.settings()->selectCategory(0,true);shell.settings()->adjustDisplay(4,1);break;
        case 19: {
            check(shell.service()=="settings" && shell.settings()->rowFocus()==4,"Scaling lost settings focus");
            QQuickItem* control=nullptr;
            QList<QQuickItem*> pending{window->contentItem()};
            while(!pending.isEmpty()) {
                auto* item=pending.takeLast();
                if(item->objectName()=="settings-control-4") {control=item;break;}
                pending.append(item->childItems());
            }
            check(control && control->isVisible(),"Size control is unavailable");
            if(control) {
                const auto bounds=control->mapRectToScene(control->boundingRect());
                check(bounds.top()>0 && bounds.bottom()<window->height(),"Scale setting is clipped after enlargement");
            }
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/settings-scale.png"),"Scale settings capture");
            shell.settings()->resetDisplayScale();shell.goToSection("home");window->resize(3840,2160);break;
        }
        case 20: {
            auto* view=window->findChild<QQuickItem*>("viewport");
            const auto mapped=view->mapRectToScene(view->boundingRect());
            check(qAbs(mapped.width()-3840)<1 && qAbs(mapped.height()-2160)<1,"4K scene does not cover output");
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/home-4k.png"),"4K capture");
            window->resize(800,450);shell.dispatch(trainer::Action::SystemMenu);shell.activate(0);
            shell.settings()->selectCategory(0,true);
            for(int i=0;i<10;i++)shell.settings()->adjustDisplay(4,1);break;
        }
        case 21: {
            auto* view=window->findChild<QQuickItem*>("viewport");
            check(view->width()>=799.9 && view->height()>=449.9,"Enlargement hides recovery controls");
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/settings-small-window.png"),"Small window capture");
            shell.settings()->resetDisplayScale();break;
        }
        case 22:
            shell.dispatch(trainer::Action::Back);shell.dispatch(trainer::Action::Back);shell.dispatch(trainer::Action::Back);
            window->resize(1920,1080);shell.openGameHubFace("overview");shell.showOverview("timeline");break;
        case 23: {
            auto* timeline=window->findChild<QQuickItem*>("game-timeline");
            check(timeline && timeline->isVisible(),"Horizontal timeline is not visible");
            check(shell.gameHistory().isEmpty(),"Empty fixture acquired invented sessions");
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/timeline-empty.png"),"Empty timeline capture");
            shell.dispatch(trainer::Action::Back);break;
        }
        case 24:
            check(shell.overviewFace()=="summary","Timeline Back did not restore Overview");
            shell.activate(0,"overview-screens");break;
        case 25:
            check(shell.overviewFace()=="screens","Overview media action did not open Screens");
            check(window->findChild<QQuickItem*>("screens-album")->isVisible(),"Album is not visible");
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/album-empty.png"),"Empty album capture");
            shell.dispatch(trainer::Action::Back);break;
        case 26:
            check(shell.overviewFace()=="summary" && shell.focusIndex()==1,"Screens Back lost media focus");
            if(!directory.isEmpty())check(window->grabWindow().save(directory+"/overview-empty-final.png"),"Empty overview capture");
            break;
        case 27:
            *artWaits=0;
            shell.goToSection("home");window->resize(800,450);shell.openGameHubFace("adapter");shell.selectAdapterScreen("party");shell.showAdapterMenu();break;
        case 28:
            if (++*artWaits < 15) {
                auto* viewport=window->findChild<QQuickItem*>("viewport");
                const auto bounds=viewport->mapRectToScene(viewport->boundingRect());
                bool ready=*artWaits>=3 && qAbs(bounds.x())<1 && qAbs(bounds.y())<1
                    && qAbs(bounds.width()-window->width())<1 && qAbs(bounds.height()-window->height())<1;
                for(const auto& id:QStringList{"party","boxes","dex","center","shops","playroom"}) {
                    auto* tile=find("adapter-screen-"+id);ready &= tile && tile->property("artworkReady").toBool();
                }
                if(!ready){--*stage;break;}
            }
            {
                auto* viewport=window->findChild<QQuickItem*>("viewport");const auto bounds=viewport->mapRectToScene(viewport->boundingRect());
                check(qAbs(bounds.x())<1 && qAbs(bounds.y())<1 && qAbs(bounds.width()-800)<1 && qAbs(bounds.height()-450)<1,"800x450 home fills the viewport after resize");
            }
            check(shell.adapterMenuOpen() && find("adapter-home"),"Ordinary entry opens adapter home");
            check(shell.adapterMenu().size()==9,"All module screens are available from home");
            for(const auto& id:QStringList{"party","boxes","dex","center","shops","playroom"}) {
                auto* tile=find("adapter-screen-"+id);check(tile && tile->property("artworkReady").toBool(),"Generated sticker loaded: "+id);
            }
            check(!find("navigation-chassis"),"Home has no permanent section tabs");
            check(window->grabWindow().save(directory+"/adapter-home-800.png"),"Home capture");
            shell.selectAdapterScreen("party");shell.showAdapterMenu();
            shell.dispatch(trainer::Action::Right);shell.dispatch(trainer::Action::Down);shell.dispatch(trainer::Action::Confirm);break;
        case 29:
            check(shell.adapterScreen()=="shops" && !shell.adapterMenuOpen(),"Grid navigation opens chosen space");
            shell.dispatch(trainer::Action::NextFace);break;
        case 30:
            check(shell.adapterScreen()=="playroom","R2 switches actual neighboring sections");
            shell.selectAdapterScreen("dex");break;
        case 31:
            shell.dispatch(trainer::Action::Back);break;
        case 32:
            check(shell.adapterMenuOpen() && shell.adapterMenuFocus()==2,"Back returns to selected home sticker");
            click("adapter-screen-boxes");break;
        case 33:
            check(shell.adapterScreen()=="boxes" && !shell.adapterMenuOpen(),"Pointer opens a full workspace");
            check(!find("adapter-screen-menu"),"Workspace has no persistent sticker menu");
            check(window->grabWindow().save(directory+"/adapter-boxes-800.png"),"Workspace capture");
            shell.dispatch(trainer::Action::Secondary);check(shell.quickAppsOpen(),"X preserved");shell.dispatch(trainer::Action::Back);
            shell.dispatch(trainer::Action::ToggleContinue);check(shell.drawerOpen(),"Y preserved");shell.dispatch(trainer::Action::Back);
            shell.dispatch(trainer::Action::SystemMenu);check(shell.menuOpen(),"Start preserved");shell.dispatch(trainer::Action::Back);
            click("adapter-home-button");break;
        case 34:
            check(shell.adapterMenuOpen() && shell.adapterMenuFocus()==1,"Pointer return preserves selected sticker");
            shell.settings()->cycleTheme();window->resize(960,540);break;
        case 35:
            check(window->grabWindow().save(directory+"/adapter-home-dark-960.png"),"Dark home capture");
            select(racing->matchGame);shell.openGameHubFace("adapter");break;
        case 36:
            check(shell.adapterMenuOpen() && shell.adapterMenu().size()==3,"Independent adapter supplies its own home");
            check(window->grabWindow().save(directory+"/adapter-independent-home.png"),"Independent home capture");
            click("adapter-screen-second");break;
        case 37:
            check(shell.adapterScreen()=="second" && !shell.adapterMenuOpen(),"Independent adapter opens without game-specific host rules");
            shell.dispatch(trainer::Action::PreviousFace);check(shell.adapterScreen()=="counter","Independent L2 navigation");
            shell.dispatch(trainer::Action::Back);break;
        case 38:
            check(shell.adapterMenuOpen() && shell.adapterMenuFocus()==0,"Independent Back returns home");
            {const auto saved=shell.navigationState();shell.goToSection("home");shell.restoreNavigation(saved);check(shell.adapterMenuOpen(),"Home survives navigation restoration");}
            shell.dispatch(trainer::Action::Back);check(shell.primaryId()=="home","Back from landing returns system Home");break;
        case 39:
            *artWaits=0;
            select(rpg->matchGame);window->resize(800,450);shell.openGameHubFace("adapter");
            shell.selectAdapterScreen("hall");shell.showAdapterMenu();break;
        case 40:
            if (++*artWaits < 15) {
                bool ready=true;for(const auto& id:QStringList{"profile","journey","hall"}) {
                    auto* tile=find("adapter-screen-"+id);ready &= tile && tile->property("artworkReady").toBool();
                }
                if(!ready){--*stage;break;}
            }
            check(window->grabWindow().save(directory+"/adapter-home-more-800.png"),"Remaining stickers capture");
            for(const auto& id:QStringList{"profile","journey","hall"}) {
                auto* tile=find("adapter-screen-"+id);check(tile && tile->property("artworkReady").toBool(),"Remaining sticker loaded: "+id);
            }
            break;
        default:
            timer->stop();completed=true;
            QFile report(directory+"/experience-check.txt");if(report.open(QIODevice::WriteOnly))report.write((diagnostics.join('\n')+QString("\nqmlWarnings=%1\n").arg(warnings)).toUtf8());
            QCoreApplication::exit(*failed || warnings?4:0);
        }
    });timer->start();
}
