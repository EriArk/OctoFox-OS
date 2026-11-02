#pragma once
#include "Models.h"
#include "GamePlayers.h"

namespace trainer {
// User intent is separate from scraped facts and verified emulator identities.
// These are implemented platform routes, not a promise that every title works.
inline QVariantList multiplayerModeOptions(const QString& platform) {
    QVariantList result;
    const auto add=[&](QString id,QString label,QString detail){result.append(QVariantMap{{"id",id},{"label",label},{"detail",detail}});};
    if(QStringList{"gb","gbc","gba","ngp","ngpc"}.contains(platform))add("link","Link","Separate handhelds and screens");
    else if(QStringList{"psp","nds","n3ds","psvita"}.contains(platform))add("wireless","Wireless","Each player uses their own system");
    else if(QStringList{"xbox","model3","doom"}.contains(platform))add("lan","In-game multiplayer",platform=="xbox"?"System Link":platform=="model3"?"Linked cabinets":"Co-op or deathmatch");
    else if(QStringList{"nes","fds","snes","sg1000","mastersystem","megadrive","segacd","sega32x","pcengine","pcenginecd","supergrafx","atari2600","psx","ps2","neogeo","fbneo","mame","neogeocd","n64","gc","wii","dreamcast","naomi","naomi2","atomiswave"}.contains(platform))add("netplay","Netplay","Controllers on a shared emulated system");
    if(QStringList{"ps2","gc","naomi","naomi2","atomiswave"}.contains(platform))add("lan","LAN / cabinet link","Separate systems; choose the network mode in-game");
    if(QStringList{"nds","n3ds","wii","wiiu","dreamcast"}.contains(platform))add("online","Online in-game","Native online service; account and game support may be required");
    return result;
}
inline QString multiplayerMode(const QJsonObject& profile) {
    const auto id=profile["id"].toString();
    if(id.startsWith("runtime.nintendo.")||id=="runtime.melonds.wfc.v1"||id=="runtime.flycast.online.v1")return "online";
    if(id=="runtime.armsx2.lan.v1"||id=="runtime.dolphin.bba.v1"||id=="runtime.flycast.cabinet.v1"||id=="runtime.xemu.lan.v1"||id=="runtime.supermodel.link.v1"||id=="runtime.odamex.doom.v1")return "lan";
    if(id=="runtime.ngpc.link.v1"||requiresLinkedSavePreparation(profile)||profile["transport"]=="netpacket"||profile["settings"]=="dcgb-linked-pair-volatile-v1")return "link";
    if(id.startsWith("runtime.ppsspp.")||id=="runtime.melonds.nds.v1"||id=="runtime.azahar.3ds.v1"||id=="runtime.vita3k.lan.v1")return "wireless";
    return "netplay";
}
inline bool validMultiplayerPreference(const QString& platform,const QJsonObject& value) {
    const auto availability=value["availability"].toString(),mode=value["mode"].toString();
    if(!QStringList{"auto","multiplayer","solo"}.contains(availability)||value.size()!=2)return false;
    if(mode=="auto")return !multiplayerModeOptions(platform).isEmpty();
    for(const auto& option:multiplayerModeOptions(platform))if(option.toMap()["id"]==mode)return true;
    return false;
}
inline QJsonObject multiplayerPreference(const AdventureRegistration& game) {
    const auto value=game.integrationConfig["multiplayerPreference"].toObject();
    return validMultiplayerPreference(game.adventure.platformId,value)?value:QJsonObject{{"availability","auto"},{"mode","auto"}};
}
inline bool permitsMultiplayer(const AdventureRegistration& game,const QVariantMap& metadata,const QJsonObject& profile) {
    const auto preference=multiplayerPreference(game);
    if(preference["availability"]=="solo"||profile.isEmpty())return false;
    if(preference["mode"]!="auto"&&preference["mode"].toString()!=multiplayerMode(profile))return false;
    return preference["availability"]=="multiplayer"||permitsMultiplayer(metadata,profile);
}
}
