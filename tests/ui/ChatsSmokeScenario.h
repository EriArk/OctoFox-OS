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
        {"friends",QVariantList{QVariantMap{{"id","mika"},{"name","Mika"},{"type",1}},QVariantMap{{"id","ren"},{"name","Ren"},{"type",1}},QVariantMap{{"id","sol"},{"name","Sol"},{"type",3}}}},
        {"chats",QVariantList{trainer::HomeSocialFixture::chat("dm","mika","Mika"),QVariantMap{{"id","group"},{"name","Weekend crew"},{"kind","groups"},{"lastInteraction",900},{"detail","Tonight at 8?"},{"unread",2}},QVariantMap{{"id","room-service"},{"kind","groups"},{"socialHidden",true}}}},
        {"messages",QVariantList{QVariantMap{{"id","m1"},{"author","mika"},{"name","Mika"},{"text","Ready for tonight?"}}}}});
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
        switch((*step)++) {
        case 0:window->resize(960,540);shell.openOnlineFace("chats");trainer::HomeSocialFixture::publish(*shell.social(),*fixture);break;
        case 1:
            check(shell.social()->rows().size()==1,"Messages excludes groups and unused contacts");
            for(const auto& id:{"friends","chats","groups","communities","contacts"})check(find("online-chat-"+QString(id)),"Rail section: "+QString(id));
            check(find("chat-badge-chats")&&find("chat-badge-groups")&&find("chat-badge-contacts"),"Unread and request badges");
            capture("messages-light");click("online-chat-groups");break;
        case 2:check(shell.socialFace()=="groups"&&shell.social()->rows().size()==1,"Touch selects ordinary groups only");(*fixture)["channel"]="group";trainer::HomeSocialFixture::publish(*shell.social(),*fixture);break;
        case 3:
            check(find("chats-conversation"),"Group conversation beside list");capture("groups-light");
            shell.dispatch(Action::Confirm);check(shell.social()->reading(),"A enters group conversation");shell.dispatch(Action::Back);check(!shell.social()->reading(),"B returns to groups");
            shell.social()->collectionOptions();shell.social()->selectMenu(0);shell.social()->selectMenu(0);break;
        case 4:capture("create-group");click("social-menu-action-"+QString::number(shell.social()->menu().size()-1));break;
        case 5:check(*created==1&&shell.social()->menu().isEmpty(),"Touch creates group exactly once");(*fixture)["state"]="connecting";(*fixture)["status"]="Reconnecting… Your conversations will return shortly.";trainer::HomeSocialFixture::publish(*shell.social(),*fixture);shell.selectChatFace("chats");break;
        case 6:check(find("online-connection-status"),"Messages connection status");capture("messages-reconnecting");shell.selectChatFace("groups");break;
        case 7:check(find("online-connection-status"),"Groups connection status");shell.selectChatFace("communities");break;
        case 8:check(find("online-connection-status"),"Communities connection status");shell.selectChatFace("friends");break;
        case 9:check(find("online-connection-status"),"Search connection status");shell.selectChatFace("contacts");break;
        case 10:check(find("online-connection-status"),"Friends connection status");(*fixture)["state"]="connected";(*fixture)["status"]="Connected";trainer::HomeSocialFixture::publish(*shell.social(),*fixture);break;
        case 11:check(shell.social()->rows().size()==3,"Friends contains relationships and incoming request");capture("friends-light");shell.social()->activate(0);check(shell.social()->profileVisible()&&shell.social()->menu().contains("Accept friend request"),"Request selection opens explicit profile actions");break;
        case 12:capture("friend-request");shell.dispatch(Action::Back);shell.selectChatFace("chats");(*fixture)["channel"]="dm";trainer::HomeSocialFixture::publish(*shell.social(),*fixture);shell.settings()->cycleTheme();break;
        case 13:capture("messages-dark");window->resize(800,450);break;
        case 14:capture("messages-dark-800");shell.settings()->cycleTheme();click("online-chat-friends");break;
        case 15:check(shell.socialFace()=="friends","Search touch route");capture("search-800");
            shell.openOnlineFace("lobby");(*fixture)["lobbyDirectory"]=QVariantMap{{"rows",QVariantList{}},{"busy",false},{"needsJoin",false},{"status","Couldn't refresh lobbies. Try again."}};trainer::HomeSocialFixture::publish(*shell.social(),*fixture);break;
        case 16:{auto* status=find("lobby-directory-status");check(status&&status->property("text").toString().contains("Couldn't refresh"),"Lobby error stays visible");shell.openOnlineFace("chats");shell.selectChatFace("chats");shell.social()->showContacts();break;}
        case 17:check(shell.social()->menu().size()==2,"New conversation excludes requests");capture("new-conversation");shell.social()->back();shell.selectChatFace("communities");break;
        case 18:check(shell.social()->rows().isEmpty(),"Community root excludes groups");check(!find("chats-conversation"),"Community root hides stale DM");capture("communities-800");shell.dispatch(Action::Back);check(shell.chatNavigationFocused(),"B focuses rail");shell.dispatch(Action::Down);check(shell.socialFace()=="contacts"&&shell.chatNavigationFocused(),"Down selects Friends on rail");break;
        case 19:capture("rail-focused-800");shell.dispatch(Action::Right);check(!shell.chatNavigationFocused(),"Right enters Friends list");break;
        default:
            check(warnings==0,"QML warnings");timer->stop();completed=true;
            QFile file(directory+"/chats-report.json");if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(QJsonObject{{"success",diagnostics.isEmpty()},{"warnings",warnings},{"diagnostics",QJsonArray::fromStringList(diagnostics)}}).toJson());
            QCoreApplication::exit(diagnostics.isEmpty()?0:1);
        }
    });timer->start();
}
