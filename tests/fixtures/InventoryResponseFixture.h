#pragma once
#include <QJsonObject>
#include <QJsonArray>

namespace trainer {
// Isolated wire fixture for unrelated game kinds; never used by production.
inline QJsonObject inventoryResponse(const QString& player,int offset=0,int count=60,int total=61,QString revision="1") {
    QJsonArray rows;
    for(int i=offset;i<offset+count;++i) {
        const bool equipment=i%2;
        const QJsonObject presentation{
            {"title",QString(equipment?"Iron shield %1":"Rally car %1").arg(i+1)},
            {"game",equipment?"Fixture RPG":"Fixture Racer"},{"subtitle",equipment?"Iron":"Sport"},
            {"icon",equipment?"shield":"gamepad"},
            {"facts",QJsonArray{QJsonObject{{"label","Type"},{"value",equipment?"Equipment":"Vehicle"}}}}
        };
        rows.append(QJsonObject{
            {"id",QString("00000000-0000-4000-8000-%1").arg(i+1,12,10,QChar('0'))},
            {"game_id",equipment?"fixture.rpg":"fixture.racer"},{"adapter_id","fixture.adapter"},{"payload_version",1},
            {"kind",equipment?"equipment":"vehicle"},{"state","stored"},{"actions",QJsonArray{}},
            {"presentation",presentation}
        });
    }
    return {{"version",1},{"player_id",player},{"revision",revision},{"total",total},{"items",rows},
        {"next",offset+count<total?QJsonValue(QString::number(total-offset-count+1)):QJsonValue(QJsonValue::Null)},
        {"transfers_available",false}};
}
}
