#include "AvatarScene.h"
#include "features/home/HomeCompanion.h"
#include "features/trainer/AvatarAssets.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QDir>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <QFile>
#include <QTest>
using namespace trainer;
int main(int argc,char** argv){
    QGuiApplication app(argc,argv);app.setOrganizationName("TrainerOS-tests");app.setApplicationName("Companion-preview");
    const QString output=argc>1?argv[1]:".";QDir().mkpath(output);
    QTemporaryDir cache;auto appearance=AvatarAssets::defaults();
    if(argc>2&&QString::fromUtf8(argv[2])=="racing"){
        appearance["top"]="rose-racing-suit";appearance["shoes"]="rose-racing-boots";
        appearance["hair"]="bob";appearance["eyes"]="determined-feminine";
    }
    const auto avatar=AvatarAssets::resolve(appearance,{},cache.path());
    if(avatar.contains("error")){qCritical()<<avatar;return 2;}
    HomeCompanion care;care.setOwner("preview-"+QUuid::createUuid().toString());
    qmlRegisterType<AvatarScene>("TrainerOS",1,0,"AvatarScene");
    qmlRegisterType(QUrl::fromLocalFile(QString(SOURCE_ROOT)+"/sdk/qt/AvatarView3D.qml"),"TrainerOS",1,0,"AvatarView3D");
    qmlRegisterSingletonType(QUrl::fromLocalFile(QString(SOURCE_ROOT)+"/src/qml/Theme.qml"),"TrainerOS",1,0,"Theme");
    QQmlApplicationEngine engine;QStringList warnings;
    QObject::connect(&engine,&QQmlEngine::warnings,&app,[&](const QList<QQmlError>& errors){for(const auto& e:errors)warnings.append(e.toString());});
    engine.rootContext()->setContextProperty("care",&care);
    engine.rootContext()->setContextProperty("resolvedModel",QUrl::fromLocalFile(avatar["glb"].toString()));
    engine.rootContext()->setContextProperty("sourceRoot",QUrl::fromLocalFile(SOURCE_ROOT).toString());
    engine.load(QUrl::fromLocalFile(QString(SOURCE_ROOT)+"/tests/home-companion-preview/Preview.qml"));
    if(engine.rootObjects().isEmpty())return 3;
    auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());if(!window)return 4;
    int step=0;QTimer timer;timer.setInterval(1800);
    QObject::connect(&timer,&QTimer::timeout,&app,[&]{
        auto capture=[&](const QString& name){const auto image=window->grabWindow();if(image.isNull()||!image.save(output+"/"+name+".png"))warnings.append("Screenshot failed: "+name);};
        if(argc>2&&QString::fromUtf8(argv[2])=="foods"){
            if(step<18){if(step%3==0)care.perform(0);if(step%3==1)capture(QFileInfo(care.prop()).baseName());++step;return;}
            QFile report(output+"/result.json");if(!report.open(QIODevice::WriteOnly)){app.exit(6);return;}
            report.write(QJsonDocument(QJsonObject{{"warnings",QJsonArray::fromStringList(warnings)}}).toJson());app.exit(warnings.isEmpty()?0:5);return;
        }
        switch(step++){
        case 0:capture("idle");QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,QPoint(82,76));if(care.activity()!="feed")warnings.append("Touch feed failed");break;
        case 1:capture("feed");break;
        case 2:capture("feed-later");break;
        case 3:QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,QPoint(254,76));if(care.activity()!="rest")warnings.append("Touch rest failed");break;
        case 4:capture("rest");care.perform(2);care.addGameplaySeconds(360);break;
        case 5:QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,QPoint(524,72));if(!care.menuOpen())warnings.append("Touch hamburger failed");break;
        case 6:capture("menu");QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,QPoint(524,72));if(care.menuOpen())warnings.append("Touch dismissal failed");break;
        case 7:care.perform(3);care.celebrate("Fixture",{"A new achievement"});break;
        case 8:capture("celebrate");break;
        case 9:care.perform(3);window->setProperty("compact",true);break;
        case 10:capture("compact");care.openHint();QMetaObject::invokeMethod(window,"hideScene");break;
        case 11:if(care.active())warnings.append("Hidden care timer remained active");QMetaObject::invokeMethod(window,"showScene");break;
        default:{
            QFile report(output+"/result.json");if(!report.open(QIODevice::WriteOnly)){app.exit(6);break;}report.write(QJsonDocument(QJsonObject{{"warnings",QJsonArray::fromStringList(warnings)},{"activeAfterReturn",care.active()}}).toJson());app.exit(warnings.isEmpty()&&care.active()?0:5);break;}
        }
    });timer.start();return app.exec();
}
