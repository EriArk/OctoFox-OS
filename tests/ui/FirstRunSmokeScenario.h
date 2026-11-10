#pragma once
#include "core/storage/SessionState.h"
#include "core/input/ControllerInput.h"
#include <QQuickWindow>
#include <QQuickItem>
#include <QMouseEvent>
#include <QTimer>
#include <QFile>
#include <QStorageInfo>
#include <QImage>
#include <memory>

inline void prepareFirstRunSmoke(trainer::SessionState& session, trainer::ShellController& shell, const QString& directory) {
    const auto root=directory+"/roms";
    session.firstRun()->configure(directory,root);
    session.firstRun()->clock()->read=[] { return trainer::ClockSnapshot{"UTC",{}, {"UTC"},true,true,true,true}; };
    session.firstRun()->locations=[root,directory](const QString&) {
        const QStorageInfo disk(directory);
        return QList<trainer::LibraryLocation>{{"Test storage",root,disk.rootPath(),QString::fromUtf8(disk.device()),disk.bytesAvailable()}};
    };
    Q_UNUSED(shell);
}

inline void startFirstRunSmoke(QQuickWindow* window, trainer::ShellController& shell, trainer::SessionState& session,
        trainer::LocalStateStore& store, trainer::ControllerInput& input, SDL_Joystick* joystick,
        const QString& directory, bool& completed, int& warnings, QStringList& diagnostics) {
    auto step=std::make_shared<int>(0), ticks=std::make_shared<int>(0);
    auto failed=std::make_shared<bool>(false);
    auto timer=new QTimer(window);timer->setInterval(350);
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&session,&store,&input,&completed,&warnings,&diagnostics] {
        auto* flow=session.firstRun();
        const auto check=[&](bool ok,const QString& text){if(!ok){*failed=true;diagnostics<<text;}};
        const auto press=[&](SDL_GameControllerButton button){SDL_JoystickSetVirtualButton(joystick,button,1);input.poll();SDL_JoystickSetVirtualButton(joystick,button,0);input.poll();};
        const auto capture=[&](const QString& name){auto frame=window->grabWindow();check(!frame.isNull(),"Empty setup frame");if(!directory.isEmpty())check(frame.save(directory+"/"+name+".png"),"Failed setup capture");};
        const std::function<QQuickItem*(QQuickItem*,const QString&)> find=[&](QQuickItem* item,const QString& name)->QQuickItem*{
            if(item->isVisible() && item->objectName()==name)return item;
            for(auto* child:item->childItems())if(auto* result=find(child,name))return result;
            return nullptr;
        };
        const auto tap=[&](const QString& name) {
            auto* item=find(window->contentItem(),name);check(item,"Missing touch target: "+name);if(!item)return;
            const auto point=item->mapToScene(QPointF(item->width()/2,item->height()/2));
            QMouseEvent down(QEvent::MouseButtonPress,point,point,Qt::LeftButton,Qt::LeftButton,Qt::NoModifier);
            QMouseEvent up(QEvent::MouseButtonRelease,point,point,Qt::LeftButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&down);QCoreApplication::sendEvent(window,&up);
        };
        if(++*ticks>130){check(false,"Setup UI timed out");*step=99;}
        switch(*step) {
        case 0:
            if(!session.firstRunPage())break;
            window->resize(960,540);++*step;break;
        case 1: capture("welcome-960");press(trainer::ControllerInput::ConfirmButton);++*step;break;
        case 2:
            check(flow->stage()=="network","Welcome did not go straight to connection");
            capture("connection-960");press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);press(trainer::ControllerInput::ConfirmButton);++*step;break;
        case 3: capture("storage-960");flow->activate(0);++*step;break;
        case 4:
            if(flow->stage()!="trainer")break;
            shell.trainerSetup()->activate(2);check(!shell.trainerSetup()->error().isEmpty(),"Missing name was accepted");
            tap("setup-choice-0");check(shell.keyboard()->isOpen(),"Name did not open shared keyboard");
            shell.keyboard()->insertText("Setup Test");shell.keyboard()->pressKey(Qt::Key_Return);++*step;break;
        case 5:
            check(!shell.keyboard()->isOpen() && shell.trainerSetup()->name()=="Setup Test","Name entry did not commit");
            press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);press(trainer::ControllerInput::ConfirmButton);++*step;break;
        case 6:
            check(shell.trainerSetup()->emblem()=="leaf","Controller did not change emblem");capture("trainer-960");
            press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);press(trainer::ControllerInput::ConfirmButton);++*step;break;
        case 7:
            if(flow->stage()!="preferences" || store.pending())break;
            check(store.trainers().size()==1,"Setup did not create exactly one Trainer");
            press(SDL_CONTROLLER_BUTTON_RIGHTSHOULDER);press(SDL_CONTROLLER_BUTTON_START);
            check(shell.page()==0 && !shell.menuOpen(),"Setup allowed global navigation");capture("comfort-960");
            press(SDL_CONTROLLER_BUTTON_DPAD_RIGHT);++*step;break;
        case 8:
            if(shell.settings()->saving())break;
            check(shell.settings()->theme()=="dark","Comfort theme was not saved");
            press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);press(SDL_CONTROLLER_BUTTON_DPAD_RIGHT);window->resize(800,480);++*step;break;
        case 9:
            check(shell.settings()->interfaceScale()==120 && flow->service().isEmpty(),"Comfort size opened settings or was not saved");
            capture("comfort-dark-large-800");press(SDL_CONTROLLER_BUTTON_DPAD_DOWN);++*step;break;
        case 10: {
            auto* item=find(window->contentItem(),"setup-choice-2");check(item,"Continue missing at large size");
            if(item){const auto p=item->mapToScene(QPointF(item->width()/2,item->height()/2));check(p.y()>0 && p.y()<window->height()-30,"Continue is outside viewport");}
            press(trainer::ControllerInput::ConfirmButton);++*step;break;
        }
        case 11: capture("accounts-dark-large-800");press(trainer::ControllerInput::ConfirmButton);++*step;break;
        case 12:
            check(flow->service()=="social" && session.setupLoginAllowed(),"TrainerOS sign-in is blocked by setup");
            capture("traineros-dark-large-800");press(SDL_CONTROLLER_BUTTON_DPAD_UP);press(trainer::ControllerInput::ConfirmButton);++*step;break;
        case 13:
            check(flow->registration(),"Controller did not open phone registration");capture("qr-fluxer-dark-large-800");
            press(trainer::ControllerInput::BackButton);check(flow->service()=="social" && !flow->registration(),"QR Back closed sign-in");
            press(trainer::ControllerInput::BackButton);press(trainer::ControllerInput::BackButton);++*step;break;
        case 14:
            check(flow->stage()=="preferences","Back from accounts lost Comfort");flow->adjustComfort(1,-1);flow->adjustComfort(0,-1);++*step;break;
        case 15:
            if(shell.settings()->saving())break;
            window->resize(960,540);flow->activate(2);++*step;break;
        case 16: capture("accounts-960");flow->activate(1);++*step;break;
        case 17: capture("achievements-960");tap("setup-registration");++*step;break;
        case 18:
            check(flow->registration(),"Touch did not open registration");capture("qr-achievements-960");tap("setup-registration-done");
            check(!flow->registration() && flow->service()=="achievements","Touch did not return to same service");session.backInSetup();flow->activate(2);++*step;break;
        case 19: capture("scraper-960");tap("setup-registration");++*step;break;
        case 20: capture("qr-scraper-960");session.backInSetup();session.backInSetup();flow->activate(3);++*step;break;
        case 21:
            capture("ready-960");press(trainer::ControllerInput::BackButton);check(flow->stage()=="accounts","Back from Ready lost accounts");
            flow->activate(3);press(trainer::ControllerInput::ConfirmButton);++*step;break;
        default:
            check(!session.blocked() && shell.page()==0,"Setup did not reach Home offline");
            capture("home-960");check(warnings==0,"QML warnings during first setup");
            timer->stop();completed=true;
            if(!directory.isEmpty()){QFile report(directory+"/verification.txt");if(report.open(QIODevice::WriteOnly))report.write(((*failed?QString("FAILED\n"):QString("PASSED\n"))+diagnostics.join('\n')).toUtf8());}
            qInfo() << (*failed?"First-run UI FAILED":"First-run UI passed: profile, comfort, optional accounts, QR, SDL, pointer and Home");
            QCoreApplication::exit(*failed?1:0);
        }
    });
    timer->start();
}
