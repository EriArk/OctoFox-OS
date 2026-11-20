// SPDX-License-Identifier: GPL-3.0-or-later
// Separate lab executable. Uses the same SDK, review window and account code as the shell.
#include "features/accounts/BackendAccount.h"
#include "features/device/ControlsDashboard.h"
#include "platform/sdk/PlatformHost.h"
#include "core/input/ControllerInput.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QDir>
#include <QQuickWindow>
#include <QTimer>

using namespace trainer;
int main(int argc,char** argv) {
    QGuiApplication app(argc,argv);
    app.setApplicationName("BazaarTradeLab");
    app.setQuitOnLastWindowClosed(false);
    const auto args=app.arguments();
    if(args.size()<4 || (args[1]!="Mika" && args[1]!="Ren"))return 2;
    QDir directory(args[2]);
    const int port=args[3].toInt();
    if(!directory.isAbsolute() || !directory.exists() || port<1 || port>65535)return 2;
    const auto wallet=directory.filePath("session.json");
    QNetworkAccessManager network;
    bool drop=args.contains("--drop-buy-response");
    BackendAccount account;
    BackendAccount::Services services;
    services.request=[&](QByteArray method,QString path,QJsonObject body,QByteArray auth,BackendAccount::Reply done){
        QNetworkRequest req(QUrl(QString("http://127.0.0.1:%1").arg(port)+path));
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,QNetworkRequest::ManualRedirectPolicy);
        req.setTransferTimeout(15000);
        req.setHeader(QNetworkRequest::ContentTypeHeader,"application/json");
        if(!auth.isEmpty())req.setRawHeader("Authorization","Bearer "+auth);
        auto* reply=network.sendCustomRequest(req,method,body.isEmpty()?QByteArray():QJsonDocument(body).toJson(QJsonDocument::Compact));
        QObject::connect(reply,&QNetworkReply::finished,&app,[reply,path,&drop,&directory,done=std::move(done)](){
            const int status=reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const auto data=QJsonDocument::fromJson(reply->readAll()).object();reply->deleteLater();
            if(path=="/v1/me/progression" && status==200){
                QSaveFile receipt(directory.filePath("balance.json"));
                if(receipt.open(QIODevice::WriteOnly)){
                    receipt.write(QJsonDocument(QJsonObject{{"balance",data["balance"]},{"player_id",data["player_id"]}}).toJson());receipt.commit();
                }
            }
            if(drop && path.endsWith("/buy") && status==200){drop=false;done(503,{});}
            else done(status,data);
        });
    };
    services.read=[&](QString,auto done){QFile f(wallet);const bool ok=f.open(QIODevice::ReadOnly);done(ok,ok?f.readAll():QByteArray());};
    services.write=[&](QString,QByteArray data,auto done){
        QSaveFile file(wallet);const bool open=file.open(QIODevice::WriteOnly);
        if(open)file.setPermissions(QFile::ReadOwner|QFile::WriteOwner);
        done(open && file.write(data)==data.size() && file.commit());
    };
    account.setServices(std::move(services));
    ControlsDashboard board;board.setOwner(args[1]);
    PlatformHost host(board);host.setBackend(&account);
    QObject::connect(&account,&BackendAccount::changed,&host,[&]{
        host.setContext({{"profile",args[1]},{"account",account.snapshot()}});
    });
    QQmlApplicationEngine engine;
    engine.setInitialProperties({{"account",QVariant::fromValue(&account)},{"labName",args[1]}});
    engine.load(QUrl("qrc:/market-lab/src/qml/MarketCheckoutWindow.qml"));
    if(engine.rootObjects().isEmpty())return 3;
    ControllerInput input;
    input.setEnabled(false);
    bool open=false;
    QObject::connect(&account,&BackendAccount::changed,&app,[&]{
        const bool visible=!account.marketReview().isEmpty();
        if(visible==open)return;
        open=visible;input.setEnabled(open);input.requireNeutral();
    });
    QObject::connect(&input,&ControllerInput::action,&app,[&](Action action){
        if(!open)return;
        if(action==Action::Confirm)emit account.marketControl("confirm");
        else if(action==Action::Back)emit account.marketControl("back");
        else if(action==Action::Up||action==Action::Left)emit account.marketControl("up");
        else if(action==Action::Down||action==Action::Right)emit account.marketControl("down");
    });
    // Drive the real window's pad actions only in the explicitly requested QA run.
    QString lastView;bool refusedRental=false;
    if(args.contains("--rehearse"))QObject::connect(&account,&BackendAccount::changed,&app,[&]{
        const auto view=account.marketReview();
        const auto text=view["text"].toString();
        if(text.isEmpty()){lastView.clear();return;}
        if(view["loading"].toBool() || text==lastView || (!view["ready"].toBool() && !view.contains("items") && !view["inventory"].toBool()))return;
        lastView=text;
        QTimer::singleShot(450,&app,[&,text]{
            const auto review=account.marketReview();
            if(review["text"]!=text)return;
            auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
            if(window)window->grabWindow().save(directory.filePath("review.png"));
            if(review["inventory"].toBool() && !review["picker"].toBool()){
                if(text.contains("Oran Berry") && text.contains("stored")){
                    if(window)window->grabWindow().save(directory.filePath("received-item.png"));
                    emit account.marketControl("back");
                }
                return;
            }
            if(text.contains("Stall 2 for 7 days") && !refusedRental){
                refusedRental=true;emit account.marketControl("back");return;
            }
            int down=1;
            if(review["picker"].toBool()) {
                const auto items=review["items"].toList();down=0;
                for(int i=0;i<items.size();++i)if(items[i].toMap()["title"]==(args.contains("--stock-pecha")?"Pecha Berry":"Oran Berry"))down=i+1;
                if(!down)return;
            } else if(!(text.contains("250 Sparks") && text.contains("Frog")) && !text.contains("65 Sparks"))return;
            for(int i=0;i<down;++i)emit account.marketControl("down");
            emit account.marketControl("confirm");
        });
    });
    app.installEventFilter(&input);
    // Read the same private profile inventory as the shell in a fresh process.
    bool requested=false;
    if(args.contains("--inventory-report"))QObject::connect(&account,&BackendAccount::changed,&app,[&]{
        if(requested || !account.inventoryConnected())return;
        requested=true;
        account.readInventory({},{},[&](int status,QJsonObject result){
            if(status!=200){app.exit(5);return;}
            QSaveFile output(directory.filePath("inventory.json"));
            if(!output.open(QIODevice::WriteOnly) || output.write(QJsonDocument(result).toJson())<0 || !output.commit()){app.exit(6);return;}
            app.quit();
        });
    });
    account.configure(args[1]);QString error;
    if(!host.start(directory.filePath("sdk/endpoint.json"),&error))return 4;
    return app.exec();
}
