// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "features/accounts/BackendAccount.h"
#include "platform/sdk/PlatformHost.h"
#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QTcpSocket>
#include <QUuid>
#include <QtTest>

namespace trainer {
// A signed-in test wallet and a desk connected through the public SDK socket.
// The PostgreSQL tests separately cover checkout, balances and ticket ownership.
struct FestivalTicketPeer {
    BackendAccount account;
    QTcpSocket desk;
    QString player=QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString ticket=QUuid::createUuid().toString(QUuid::WithoutBraces);
    bool funded=false, consumed=false;

    void attach(PlatformHost& host,const QString& endpoint,const QString& profile) {
        BackendAccount::Services services;
        services.read=[](QString,auto done){done(true,QJsonDocument(QJsonObject{{"refresh_token",QString(43,'r')}}).toJson());};
        services.write=[](QString,QByteArray,auto done){done(true);};
        services.request=[this](QByteArray verb,QString path,QJsonObject body,QByteArray,BackendAccount::Reply done){
            if(path=="/v1/auth/refresh") {
                done(200,{{"player_id",player},{"session_id",player},{"fluxer_subject","12345"},
                          {"refresh_token",QString(43,'r')},{"access_token",QString(43,'a')},
                          {"expires_at",QDateTime::currentDateTimeUtc().addSecs(900).toString(Qt::ISODateWithMs)}});
            } else if(path=="/v1/me/profile")done(200,{{"player_id",player},{"display_name","Entrant"}});
            else if(path=="/v1/me/festival/golf_online" && verb=="GET")
                done(200,{{"player_id",player},{"round",funded?QJsonObject{{"id",ticket},{"complete",consumed}}:QJsonObject{}}});
            else if(path=="/v1/me/festival/golf_online/"+ticket+"/attempt" && verb=="POST" && funded
                    && body==QJsonObject{{"index",0},{"x",0},{"y",0}}) {
                consumed=true;
                done(200,{{"player_id",player},{"round",QJsonObject{{"id",ticket},{"complete",true}}}});
            } else done(404,{});
        };
        account.setServices(std::move(services));
        account.configure(profile);
        host.setBackend(&account);
        QFile file(endpoint);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const auto info=QJsonDocument::fromJson(file.readAll()).object();
        desk.connectToHost(QHostAddress::LocalHost,info["port"].toInt());
        QVERIFY(desk.waitForConnected(2000));
        QVERIFY(call("hello",{{"token",info["token"]},{"protocol",1},{"app","org.traineros.bazaar.festival"}}).contains("result"));
    }

    QJsonObject call(const QString& method,const QJsonObject& args={}) {
        desk.write(QJsonDocument(QJsonObject{{"id","test"},{"method",method},{"params",args}}).toJson(QJsonDocument::Compact)+"\n");
        QElapsedTimer elapsed;elapsed.start();
        while(elapsed.elapsed()<3000){
            if(!desk.canReadLine()){QTest::qWait(5);continue;}
            const auto packet=QJsonDocument::fromJson(desk.readLine()).object();
            if(packet["id"]=="test")return packet;
        }
        return {};
    }
};
}
