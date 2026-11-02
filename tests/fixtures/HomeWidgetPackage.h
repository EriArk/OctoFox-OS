#pragma once
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
inline QVariantMap homeWidgetPackage(const QString& root,const QString& sha=QString(64,'a')) {
    const auto object="home-companion-"+sha;const auto path=root+"/objects/"+object;
    QDir().mkpath(path);
    QFile manifest(path+"/home-widgets.json");if(!manifest.open(QIODevice::WriteOnly))return {};
    manifest.write(QJsonDocument(QJsonObject{{"schema",1},{"app","home-companion"},{"widgets",QJsonArray{
        QJsonObject{{"id","pet"},{"title","Companion"},{"renderer","avatar-care-v1"},{"assets","assets"}}}}}).toJson());
    const QStringList assets={"backgrounds/cozy-room.png","backgrounds/sunny-garden.png","backgrounds/evening-nook.png",
        "furniture-kit/loungeChair.glb","food-kit/apple.glb","food-kit/banana.glb","food-kit/burger.glb",
        "food-kit/cookie-chocolate.glb","food-kit/cup-tea.glb","food-kit/cupcake.glb"};
    for(const auto& name:assets){const auto file=path+"/assets/"+name;QDir().mkpath(QFileInfo(file).path());QFile f(file);if(!f.open(QIODevice::WriteOnly))return {};f.write("fixture");}
    return {{"id","home-companion"},{"kind","app"},{"object",object},{"sha256",sha},{"version","0.1.0"}};
}
