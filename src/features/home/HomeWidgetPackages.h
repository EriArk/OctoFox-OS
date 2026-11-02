#pragma once
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <QUrl>
#include <QVariantList>

namespace trainer {
// Installed declarative contributions only. Renderer code belongs to the host;
// an archive never supplies QML, a native plugin or a path to executable UI.
inline QVariantList installedHomeWidgets(const QString& root, const QVariantList& receipts) {
    QVariantList result;
    const QRegularExpression id("^[a-z0-9][a-z0-9-]{0,63}$"), hash("^[a-f0-9]{64}$");
    const auto objects=QFileInfo(root+"/objects").canonicalFilePath();
    if(objects.isEmpty())return result;
    for(const auto& value:receipts) {
        const auto r=value.toMap();const auto package=r["id"].toString(),sha=r["sha256"].toString();
        if(r["kind"]!="app" || !id.match(package).hasMatch() || !hash.match(sha).hasMatch()
            || r["object"]!=package+"-"+sha)continue;
        const auto path=objects+"/"+r["object"].toString();
        if(QFileInfo(path).isSymLink() || QFileInfo(path).canonicalFilePath()!=path)continue;
        QFile file(path+"/home-widgets.json");
        if(QFileInfo(file).isSymLink() || file.size()>16384 || !file.open(QIODevice::ReadOnly))continue;
        const auto manifest=QJsonDocument::fromJson(file.readAll()).object();
        const auto widgets=manifest["widgets"].toArray();
        if(manifest["schema"].toInt()!=1 || manifest["app"]!=package || widgets.isEmpty() || widgets.size()>8)continue;
        QSet<QString> seen;QVariantList rows;bool valid=true;
        for(const auto& item:widgets) {
            const auto w=item.toObject();const auto local=w["id"].toString(),title=w["title"].toString().trimmed();
            const auto renderer=w["renderer"].toString(),assets=w["assets"].toString();
            if(!id.match(local).hasMatch() || seen.contains(local) || title.isEmpty() || title.size()>64
                || renderer!="avatar-care-v1" || !id.match(assets).hasMatch()) {valid=false;break;}
            const auto base=path+"/"+assets;
            if(QFileInfo(base).isSymLink() || QFileInfo(base).canonicalFilePath()!=base || !QFileInfo(base).isDir()){valid=false;break;}
            // This renderer's asset contract is fixed and versioned. Reject partial
            // installations rather than showing an empty scene or qrc fallback.
            const QStringList required={"backgrounds/cozy-room.png","backgrounds/sunny-garden.png","backgrounds/evening-nook.png",
                "furniture-kit/loungeChair.glb","food-kit/apple.glb","food-kit/banana.glb","food-kit/burger.glb",
                "food-kit/cookie-chocolate.glb","food-kit/cup-tea.glb","food-kit/cupcake.glb"};
            for(const auto& name:required){const QFileInfo f(base+"/"+name);if(!f.isFile() || f.isSymLink()
                || !f.canonicalFilePath().startsWith(base+"/") || f.size()==0 || f.size()>16*1024*1024){valid=false;break;}}
            if(!valid)break;
            seen.insert(local);
            rows.append(QVariantMap{{"id","crates:"+package+":"+local},{"package",package},{"localId",local},
                {"title",title},{"renderer",renderer},{"assetBase",QUrl::fromLocalFile(base+"/").toString()},
                {"version",r["version"]}});
        }
        if(valid)result.append(rows);
    }
    return result;
}
}
