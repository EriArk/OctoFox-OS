// SPDX-License-Identifier: GPL-3.0-or-later
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
#include <QImage>
#include <QSet>
int main(int argc,char** argv){
    QGuiApplication app(argc,argv);if(argc<3)return 2;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("fixture",QVariantMap{{"source",QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1]))}});
    engine.loadData(R"(import QtQuick
import QtQuick.Window
Window {width:500;height:260;visible:true;color:"#f4f0e6"
PlayerCard {x:20;y:28;width:300;height:180;descriptor:fixture;label:"YOU";detail:"MINT";current:true}
})",QUrl::fromLocalFile(QString(PORTRAIT_QML)+"Preview.qml"));
    if(engine.rootObjects().isEmpty())return 3;
    auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    QTimer::singleShot(6000,&app,[&]{
        auto* renderer=window->findChild<QObject*>("portraitRenderer");
        bool stopped=renderer&&!renderer->property("active").toBool();
        const auto frame=window->grabWindow();QSet<QRgb> portraitColours;
        // Exclude text/borders: a transparent 3D capture used to pass this check.
        for(int y=50;y<175&&y<frame.height();++y)for(int x=50;x<170&&x<frame.width();++x)
            portraitColours.insert(frame.pixel(x,y));
        app.exit(frame.save(QString::fromLocal8Bit(argv[2]))&&stopped&&portraitColours.size()>128?0:4);
    });
    return app.exec();
}
