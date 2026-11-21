// SPDX-License-Identifier: GPL-3.0-or-later
#include "SdkNetwork.h"

namespace trainer {
namespace {
const QString Golf = QStringLiteral("art.abysstail.pocket-golf");
const QString Desk = QStringLiteral("org.traineros.bazaar.festival");
const QString Cup = QStringLiteral("Festival Cup / Pocket Golf");
QJsonArray entrants(const QJsonObject& room) {
    QJsonArray rows;
    for (const auto& entry : room["members"].toArray()) {
        const auto member=entry.toObject();
        if (member["connected"].toBool() && !member["spectator"].toBool())
            rows.append(QJsonObject{{"name",member["name"]},{"id",member["id"]},{"ready",member["ready"]}});
    }
    return rows;
}
bool cupGame(const QJsonObject& room) {
    const auto game=room["game"].toObject();
    return game["title"]==Cup && game["runtime"].toObject()["app"]==Golf;
}
}

void SdkNetwork::clearCup() {
    cupRoom_.clear();cupOwner_.clear();cupGeneration_=0;cupTicket_.clear();cupMatch_.clear();cupPlayers_.clear();cupBoard_={};
}

void SdkNetwork::observeCupScore(const QString& app,const QString& ticket,const QString& method,const QJsonObject& result) {
    if(app!=Golf || ticket.isEmpty() || ticket!=cupTicket_ || cupOwner_!=lobby_.self())return;
    if(method=="play.create" || method=="play.join"){
        const auto row=result["match"].toObject();
        if(cupMatch_.isEmpty() && row["ruleset_id"]=="pocket-golf.island.open7.v1" && row["mode"]=="individual" && row["seats"].toArray()==QJsonArray{1,1})
            cupMatch_=row["id"].toString();
        return;
    }
    if(method!="play.get" || cupMatch_.isEmpty() || result["id"]!=cupMatch_)return;
    const auto state=result["state"].toString();
    if(state!="confirmed" && state!="disputed" && state!="rejected" && state!="voided" && state!="cancelled")return;
    QJsonArray rows;
    for(const auto& v:result["outcomes"].toArray()){
        const auto r=v.toObject();
        QString name;
        const auto ids=r["members"].toArray();
        for(const auto& participant:result["participants"].toArray()){
            const auto player=participant.toObject();
            if(ids.contains(player["player_id"]))name=cupPlayers_.value(player["side"].toInt(-1));
        }
        rows.append(QJsonObject{{"place",r["place"]},{"score",r["score"]},{"name",name}});
    }
    cupBoard_={{"state",state},{"rows",rows},{"ticket",ticket}};
}

QString SdkNetwork::cupRequest(const QString& app,const QString& method,const QJsonObject& args,QJsonObject& result) {
    if(method=="activity.cup.toss" && app==Desk){
        const int x=args["x"].toInt(999),z=args["z"].toInt(999);
        if(args.size()!=2 || x < -130 || x > 130 || z < -80 || z > 80)return "invalid_ring";
        lobby_.activeRoom()->tossFestivalRing(x,z);return {};
    }
    if(app==Golf && method=="activity.cup.finish"){
        if(cupTicket().isEmpty() || !cupBoard_.value("rows").isUndefined())return "cup_closed";
        const auto scores=args["strokes"].toArray();
        if(args.size()!=1 || scores.size()!=2)return "invalid_score";
        for(const auto& value:scores)if(value.toInt()<3 || value.toInt()>24)return "invalid_score";
        cupBoard_={{"state",cupMatch_.isEmpty()?"unranked":"pending"},{"strokes",scores},{"ticket",cupTicket_}};
        return {};
    }
    if(!args.isEmpty() || (app!=Desk && app!=Golf))return "unsupported_method";
    auto room=lobby_.state();
    const auto local=installed_.value(Golf);
    if(!cupOwner_.isEmpty() && cupOwner_!=lobby_.self())clearCup();
    if(app==Golf){
        if(method!="activity.cup.status")return "unsupported_method";
        result={{"entered",!cupTicket_.isEmpty() && cupTicket_==ticket_ && matches()}};
        return {};
    }
    if(method=="activity.cup.lobby"){emit openLobbyRequested();return {};}
    const auto gathering=room["phase"]=="gathering";
    bool joined=!cupRoom_.isEmpty() && cupRoom_==room["id"].toString() &&
        cupGeneration_==room["generation"].toInteger() && cupGame(room);
    if(method=="activity.cup.join"){
        if(local.isEmpty())return "install_golf";
        const auto seats=entrants(room);
        bool seated=false;
        for(const auto& seat:seats)if(seat.toObject()["id"]==lobby_.self())seated=true;
        if(!seated || seats.size()!=2 || room["members"].toArray().size()!=2)return "need_two";
        if(room["phase"]!="choosing" && !gathering)return "room_busy";
        if(!cupGame(room)){
            if(!lobby_.hosting())return "host_first";
            if(!room["game"].toObject()["id"].toString().isEmpty())return "room_busy";
            if(!lobby_.selectGame({"sdk:"+Golf,Cup,"Apps","sdk.records.v1",local["seats"].toInt(),local["runtime"].toObject()}))return "room_busy";
            room=lobby_.state();
        }
        if(room["game"].toObject()["runtime"]!=local["runtime"])return "install_golf";
        if(!joined){
            clearCup();cupOwner_=lobby_.self();cupRoom_=room["id"].toString();
            cupGeneration_=room["generation"].toInteger();joined=true;
            for(const auto& value:seats){
                const auto member=value.toObject();
                const auto name=member["name"].toString().simplified().left(12);
                if(member["id"]==room["owner"])cupPlayers_.prepend(name);
                else cupPlayers_.append(name);
            }
        }
    }else if(method=="activity.cup.leave"){
        if(joined && gathering){
            lobby_.ready(false);runtime_.cancelPending();clearCup();joined=false;
        }
    }else if(method!="activity.cup.status")return "unsupported_method";
    if(joined && room["phase"]=="gathering" && cupTicket_.isEmpty()){
        if(entrants(room).size()!=2){lobby_.ready(false);runtime_.cancelPending();clearCup();joined=false;}
        else{
            for(const auto& v:room["members"].toArray()){
                const auto m=v.toObject();
                if(m["id"]!=lobby_.self() || m["spectator"].toBool())continue;
                if(!m["prepared"].toBool() && !runtime_.busy())runtime_.prepare();
                else if(m["prepared"].toBool() && !m["ready"].toBool())lobby_.ready(true);
            }
            const auto rows=entrants(lobby_.state());
            if(lobby_.hosting() && rows.size()==2 && rows[0].toObject()["ready"].toBool() && rows[1].toObject()["ready"].toBool())lobby_.start();
        }
    }
    room=lobby_.state();
    result={{"installed",!local.isEmpty()},{"members",entrants(room)},{"joined",joined},
            {"phase",room["phase"]},{"cup",cupGame(room)},{"board",cupBoard_},{"ticket",cupTicket_}};
    return {};
}
}
