#include "AppsSmokeScenario.h"
#include <QTemporaryDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QIcon>
#include <QFileInfo>
#include <QTimer>
#include <QFile>
#include <QImage>
#include <QQuickItem>
#include <QtTest>
#include <memory>
using namespace trainer;
namespace {
QQuickItem* appsItem(QQuickItem* parent,const QString& name) {
    if(!parent)return nullptr;
    if(parent->objectName()==name)return parent;
    for(auto* child:parent->childItems())if(auto* match=appsItem(child,name))return match;
    return nullptr;
}
}
void startAppsSmoke(QQuickWindow* window,ShellController& shell,ControllerInput& input,SDL_Joystick* joystick,
        const QString& directory,bool& completed,int& warnings,QStringList& diagnostics) {
    auto temporary=std::make_shared<QTemporaryDir>();auto step=std::make_shared<int>(0);auto failed=std::make_shared<bool>(false);
    auto timer=new QTimer(window);timer->setInterval(350);
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&input,&completed,&warnings,&diagnostics]{
        auto* flow=shell.apps();
        const auto check=[&](bool ok,const QString& why){if(!ok){*failed=true;diagnostics<<why;}};
        const auto press=[&](SDL_GameControllerButton button){SDL_JoystickSetVirtualButton(joystick,button,1);input.poll();SDL_JoystickSetVirtualButton(joystick,button,0);input.poll();};
        const auto capture=[&](const QString& name){auto image=window->grabWindow();check(!image.isNull(),"Empty Apps frame");if(!directory.isEmpty())check(image.save(directory+'/'+name+".png"),"Failed to save Apps frame");};
        switch((*step)++) {
        case 0: {
            flow->configure(temporary->path(),"apps-smoke");QJsonArray rows;
            for(int i=0;i<28;++i)rows.append(QJsonObject{{"id",QString("app-%1.desktop").arg(i,2,10,QChar('0'))},{"name",QString("Application %1").arg(i,2,10,QChar('0'))}});
            flow->accept({{"event","catalogue"},{"rows",rows}});flow->accept({{"event","ready"}});
            shell.goToSection("social");press(SDL_CONTROLLER_BUTTON_RIGHTSHOULDER);break;
        }
        case 1:
            check(shell.page()==4,"R1 did not reach Apps");check(shell.primaryNames().last()=="Apps","Apps is not a primary");
            check(window->findChild<QObject*>("apps-grid") && window->findChild<QObject*>("apps-grid")->property("count").toInt()==28,"Application catalog was not rendered");
            check(shell.navigationState()["page"].toString()=="apps","Apps checkpoint identity");
            press(SDL_CONTROLLER_BUTTON_DPAD_RIGHT);check(flow->focusIndex()==1,"Apps controller focus");
            press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);check(flow->focusIndex()==6,"Five-column navigation must preserve the focused column");
            press(SDL_CONTROLLER_BUTTON_DPAD_UP);check(flow->focusIndex()==1,"Up must return to the same column");
            press(SDL_CONTROLLER_BUTTON_BACK);break;
        case 2:
            check(flow->menu().size()==4,"Select did not open Apps options");capture("apps-options");
            press(SDL_CONTROLLER_BUTTON_B);check(flow->rail().size()==1,"Favorite missing");
            press(SDL_CONTROLLER_BUTTON_BACK);press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);press(SDL_CONTROLLER_BUTTON_B);break;
        case 3:
            check(flow->rows().size()==27,"Hide did not remove catalog entry");check(flow->rail().isEmpty(),"Hidden favorite stayed in rail");
            flow->options(0);flow->menuAction(2);break;
        case 4:
            check(flow->hiddenView(),"Hidden apps context action failed");check(flow->rows().size()==1,"Hidden app missing");capture("apps-hidden");
            flow->options(0);flow->menuAction(1);flow->showHidden();
            flow->accept({{"event","state"},{"running",QJsonArray{"app-00.desktop"}},{"current",""}});
            press(SDL_CONTROLLER_BUTTON_Y);break;
        case 5:
            check(flow->railFocused(),"X cannot reach running/favorite apps");
            if (const auto preview=qEnvironmentVariable("TRAINEROS_APPS_PREVIEW_CATALOGUE");!preview.isEmpty()) {
                QFile file(preview);check(file.open(QIODevice::ReadOnly),"Cannot read real preview catalogue");
                const auto catalogue=QJsonDocument::fromJson(file.readAll()).object();
                int actualIcons=0;
                for(const auto& value:catalogue["rows"].toArray()) {
                    const auto icon=value.toObject()["icon"].toString();
                    if (!(QFileInfo(icon).isAbsolute()?QIcon(icon):QIcon::fromTheme(icon)).pixmap(64,64).isNull())++actualIcons;
                    else diagnostics<<"Missing installed icon: "+value.toObject()["name"].toString()+" ("+icon+")";
                }
                check(actualIcons>=10,"Real application icon theme did not resolve");
                diagnostics<<QString("Real catalogue icons resolved: %1 / %2").arg(actualIcons).arg(catalogue["rows"].toArray().size());
                flow->accept(catalogue);
                for(int i=0;i<4;++i){flow->options(i);flow->menuAction(0);}
                flow->select(0,true);
            }
            check(shell.quickAppsOpen(),"Global Quick Apps did not open");capture("apps-workspace");
            press(SDL_CONTROLLER_BUTTON_LEFTSHOULDER);check(shell.page()==3,"L1 did not leave Apps");press(SDL_CONTROLLER_BUTTON_RIGHTSHOULDER);
            window->resize(800,450);shell.toggleQuickApps();break;
        case 6:
            capture("apps-800");shell.toggleQuickApps();flow->select(27);break;
        case 7:
            capture("apps-scrolled-800");check(flow->focusIndex()==27,"Pointer focus and scrolling");
            shell.goToPage(ShellController::HomePage);flow->accept({{"event","foreground"},{"id","app-00.desktop"}});break;
        case 8: {
            // No corner control remains over an ordinary application's content.
            auto* overlay=window->findChild<QQuickWindow*>("app-controls-window");
            check(overlay&&!overlay->isVisible(),"App Home is visible before Home is pressed");
            if(overlay)overlay->resize(960,540);
            flow->accept({{"event","controls"}});break;
        }
        case 9: {
            auto* overlay=window->findChild<QQuickWindow*>("app-controls-window");
            check(flow->controlsOpen()&&overlay&&overlay->isVisible(),"Application Home missing");
            if(overlay&&!directory.isEmpty())check(overlay->grabWindow().save(directory+"/app-home-light.png"),"App Home screenshot failed");
            flow->accept({{"event","action"},{"action","down"}});check(flow->controlIndex()==1,"Home cannot select Minimize");
            shell.settings()->cycleTheme(1);break;
        }
        case 10: {
            auto* overlay=window->findChild<QQuickWindow*>("app-controls-window");
            if(overlay&&!directory.isEmpty())check(overlay->grabWindow().save(directory+"/app-home-dark.png"),"Dark App Home screenshot failed");
            flow->accept({{"event","action"},{"action","back"}});check(!flow->controlsOpen(),"Back did not return to app");
            flow->accept({{"event","controls"}});break;
        }
        case 11: {
            auto* overlay=window->findChild<QQuickWindow*>("app-controls-window");
            auto* minimize=overlay?appsItem(overlay->contentItem(),"app-home-action-1"):nullptr;
            check(minimize,"Minimize touch target missing");
            if(minimize)QTest::mouseClick(overlay,Qt::LeftButton,Qt::NoModifier,minimize->mapToScene(QPointF(minimize->width()/2,minimize->height()/2)).toPoint());
            check(!flow->controlsOpen(),"Touch did not minimize");
            flow->accept({{"event","shell"}});check(shell.page()==ShellController::HomePage,"Minimize lost the launching Home page");
            shell.settings()->cycleTheme(1);window->showNormal();window->resize(960,540);
            QJsonArray running;for(int i=0;i<20;++i)running.append(QString("app-%1.desktop").arg(i,2,10,QChar('0')));
            flow->accept({{"event","state"},{"running",running},{"current",""}});
            shell.toggleQuickApps();flow->select(flow->rail().size()-1,true);break;
        }
        case 12: {
            check(flow->rail().size()==20,"Quick Apps lost running apps or duplicated a favorite");
            auto* slot=appsItem(window->contentItem(),"quick-app-slot-19");
            check(slot,"Last running app has no Quick Apps icon");
            if(slot){const auto position=slot->mapToScene(QPointF(slot->width()/2,slot->height()/2));check(position.x()>0&&position.x()<window->width(),"Focused running app scrolled outside the screen");}
            capture("quick-apps-running");
            shell.openAppsFace("crates");flow->accept({{"event","error"},{"message","Application could not open"}});
            check(shell.notice()=="Application could not open","Crates launch error was hidden");break;
        }
        default:
            check(warnings==0,"Apps QML warnings");completed=true;timer->stop();
            if(!directory.isEmpty()){QFile file(directory+"/apps-verification.txt");if(file.open(QIODevice::WriteOnly))file.write(((*failed?QString("FAILED\n"):QString("PASSED\n"))+diagnostics.join('\n')).toUtf8());}
            QCoreApplication::exit(*failed?1:0);break;
        }
    });timer->start();
}
