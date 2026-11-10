#pragma once
#include "core/navigation/ShellController.h"
#include "../fixtures/HomeSocialFixture.h"
#include <QQuickWindow>
#include <QQuickItem>
#include <QTimer>
#include <QMouseEvent>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <memory>

inline void startChatsSmoke(QQuickWindow* window,trainer::ShellController& shell,const QString& directory,
    bool& completed,int& warnings,QStringList& diagnostics) {
    using trainer::Action;
    trainer::HomeSocialFixture::isolateProvider(*shell.social());
    auto step=std::make_shared<int>(0),created=std::make_shared<int>(0);
    auto timer=new QTimer(window);timer->setInterval(500);
    QObject::connect(shell.social(),&trainer::SocialController::commandRequested,timer,[created](QString op,QVariantMap){if(op=="create-group")++*created;});
    auto fixture=std::make_shared<QVariantMap>(QVariantMap{{"state","connected"},{"status","Connected"},{"userId","self"},{"name","Player"},{"channel","dm"},
        {"friends",QVariantList{QVariantMap{{"id","mika"},{"name","Mika"},{"type",1}},QVariantMap{{"id","ren"},{"name","Ren"},{"type",1}}}},
        {"chats",QVariantList{trainer::HomeSocialFixture::chat("dm","mika","Mika"),QVariantMap{{"id","group"},{"name","Weekend crew"},{"kind","groups"},{"lastInteraction",900},{"detail","Tonight at 8?"},{"unread",2}},QVariantMap{{"id","room-service"},{"kind","groups"},{"socialHidden",true}}}},
        {"messages",QVariantList{QVariantMap{{"id","m1"},{"author","mika"},{"name","Mika"},{"text","Ready for tonight?"}}}}});
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&completed,&warnings,&diagnostics]{
        const auto check=[&](bool ok,QString why){if(!ok)diagnostics.append(why);};
        const auto find=[&](QString name){
            std::function<QQuickItem*(QQuickItem*)> walk=[&](QQuickItem* item)->QQuickItem*{if(item->objectName()==name&&item->isVisible())return item;for(auto* child:item->childItems())if(auto* found=walk(child))return found;return nullptr;};
            return walk(window->contentItem());
        };
        const auto capture=[&](QString name){check(window->grabWindow().save(directory+"/"+name+".png"),"Capture "+name);};
        switch((*step)++) {
        case 0:window->resize(960,540);shell.openOnlineFace("chats");trainer::HomeSocialFixture::publish(*shell.social(),*fixture);break;
        case 1:check(shell.social()->rows().size()==2,"Inbox contains DM and group, excludes unused friend and service group");capture("chats-light");shell.social()->collectionOptions();shell.social()->selectMenu(1);shell.social()->selectMenu(0);break;
        case 2:{
            check(shell.social()->menu().last().startsWith("Create group"),"Explicit Create group action");capture("create-group");
            auto* item=find("social-menu-action-"+QString::number(shell.social()->menu().size()-1));check(item,"Create group touch target");
            if(item){auto point=item->mapToScene({item->width()/2,item->height()/2});auto global=QPointF(window->mapToGlobal(point.toPoint()));
                QMouseEvent down(QEvent::MouseButtonPress,point,global,Qt::LeftButton,Qt::LeftButton,Qt::NoModifier),up(QEvent::MouseButtonRelease,point,global,Qt::LeftButton,Qt::NoButton,Qt::NoModifier);
                QCoreApplication::sendEvent(window,&down);QCoreApplication::sendEvent(window,&up);}
            break;}
        case 3:check(*created==1&&shell.social()->menu().isEmpty(),"Touch creates group exactly once");(*fixture)["state"]="connecting";(*fixture)["status"]="Reconnecting… Your conversations will return shortly.";trainer::HomeSocialFixture::publish(*shell.social(),*fixture);shell.selectChatFace("chats");break;
        case 4:check(find("online-connection-status"),"Messages connection status");capture("chats-reconnecting");shell.selectChatFace("communities");break;
        case 5:check(find("online-connection-status"),"Communities connection status");shell.selectChatFace("friends");break;
        case 6:check(find("online-connection-status"),"Discover connection status");capture("discover-reconnecting");shell.openOnlineFace("lobby");(*fixture)["state"]="connected";(*fixture)["status"]="Connected";(*fixture)["lobbyDirectory"]=QVariantMap{{"rows",QVariantList{}},{"busy",false},{"needsJoin",false},{"status","Couldn't refresh lobbies. Try again."}};trainer::HomeSocialFixture::publish(*shell.social(),*fixture);break;
        case 7:{auto* status=find("lobby-directory-status");check(status&&status->property("text").toString().contains("Couldn't refresh"),"Lobby network failure is visible");capture("lobby-network-error");shell.openOnlineFace("chats");shell.selectChatFace("chats");shell.settings()->cycleTheme();break;}
        case 8:capture("chats-dark");window->resize(800,450);break;
        case 9:capture("chats-dark-800");shell.settings()->cycleTheme();(*fixture)["channel"]="group";trainer::HomeSocialFixture::publish(*shell.social(),*fixture);break;
        case 10:check(find("chats-conversation"),"Group conversation is visible beside inbox");capture("group-conversation");shell.social()->dispatch(Action::Confirm);check(shell.social()->reading(),"A enters selected conversation");shell.social()->dispatch(Action::Back);check(!shell.social()->reading(),"B returns to inbox");shell.social()->showContacts();break;
        case 11:capture("new-conversation");check(shell.social()->menu().size()==2,"New conversation shows unused friends");shell.social()->back();shell.selectChatFace("communities");break;
        case 12:check(shell.social()->rows().isEmpty(),"Community root excludes personal groups");check(!find("chats-conversation"),"Community root hides stale group conversation");capture("communities-root");break;
        default:
            check(warnings==0,"QML warnings");timer->stop();completed=true;
            QFile file(directory+"/chats-report.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(QJsonObject{{"success",diagnostics.isEmpty()},{"warnings",warnings},{"diagnostics",QJsonArray::fromStringList(diagnostics)}}).toJson());
            QCoreApplication::exit(diagnostics.isEmpty()?0:1);
        }
    });timer->start();
}
