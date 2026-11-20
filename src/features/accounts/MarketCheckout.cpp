#include "BackendAccount.h"
#include <QUuid>
#include <cmath>

namespace trainer {
namespace {
bool uuid(QJsonValue v) { return v.isString() && v.toString().size()==36 && !QUuid(v.toString()).isNull(); }
bool money(QJsonValue v) { return v.isDouble() && v.toInteger()>0 && v.toDouble()==double(v.toInteger()) && v.toInteger()<=2147483647; }
QJsonObject error(QString code) { return {{"code",code}}; }
bool matchesReceipt(const QJsonObject& intent,const QJsonObject& result) {
    const auto op=intent["operation_id"],player=intent["player_id"],price=intent["price"];
    if(result["player_id"]!=player)return false;
    if(intent["action"]=="list") {
        const auto row=result["listing"].toObject();
        return uuid(row["id"]) && row["operation_id"]==op && row["seller_id"]==player && row["rental_id"]==intent["rental_id"]
            && row["item_id"]==intent["item_id"] && row["price"]==price;
    }
    const auto r=result["receipt"].toObject();
    if(!uuid(r["id"]) || r["operation_id"]!=op || r["price"]!=price || QString::number(r["offer_revision"].toInteger())!=intent["revision"].toString())return false;
    if(intent["action"]=="buy")return r["kind"]=="loot" && r["buyer_id"]==player && r["listing_id"]==intent["listing_id"] && r["item_id"]==intent["item_id"];
    const auto seller=result["seller_receipt"].toObject();
    return r["place_id"]==intent["place_id"] && r["tenant_id"]==player && seller["rental_id"]==r["id"] && seller["buyer_id"]==player
        && seller["kind"]=="seller" && seller["operation_id"]==op && seller["species"]==intent["species"] && seller["price"]==intent["seller_price"];
}
}

void BackendAccount::endMarket(int status,QJsonObject result) {
    if(!marketReply_ && marketView_.isEmpty())return;
    ++marketGeneration_;
    auto reply=std::move(marketReply_);
    marketReply_={};marketIntent_={};marketView_={};marketChannel_.clear();
    if(reply)reply(status,std::move(result));
    emit changed();
}

void BackendAccount::closeMarketReview(const QString& channel) {
    if(channel==marketChannel_ && !marketSending_)endMarket(409,error("review_cancelled"));
}

void BackendAccount::marketCheckout(QString channel,const QJsonObject args,Reply done) {
    if(!inventoryConnected()){done(401,error("sign_in_required"));return;}
    if(marketSending_ || marketReply_ || shopBusy_ || !shopPending_.isEmpty()){done(409,error("checkout_busy"));return;}
    const QString action=args["action"].toString();
    const auto price=args["price"],slot=args["slot"];
    if(action!="resolve" && action!="inventory" && (slot.toInt()<1 || slot.toInt()>12 || !money(price))){done(422,error("invalid_offer"));return;}
    const bool valid=((action=="resolve" || action=="inventory") && args.size()==1) ||
        (action=="rent" && args.size()==6 && args["species"].isString() && money(args["seller_price"]) && args.contains("revision")) ||
        (action=="list" && args.size()==3) ||
        (action=="buy" && args.size()==5 && uuid(args["listing_id"]) && args.contains("revision"));
    if(!valid){done(422,error("invalid_offer"));return;}
    if(!marketPending_.isEmpty() && action!="resolve" && action!="inventory"){done(409,error("checkout_pending"));return;}
    marketReply_=std::move(done);marketChannel_=channel;
    const auto generation=++marketGeneration_;
    if(action=="inventory") {
        marketIntent_=args;
        marketView_={{"text","Your profile inventory"},{"picker",true},{"inventory",true}};
        moreMarketItems();return;
    }
    if(action=="resolve") {
        if(marketPending_.isEmpty() || marketPending_["player_id"]!=player_){endMarket(404,error("no_pending_checkout"));return;}
        marketIntent_=marketPending_;marketView_={{"text",marketIntent_["summary"]},{"ready",true},{"retry",true}};emit changed();return;
    }
    bazaarRead("bazaar.world",{},[this,args,action,generation](int status,QJsonObject world){
        if(generation!=marketGeneration_)return;
        if(status!=200 || world["payments_available"]!=true){endMarket(409,error("market_closed"));return;}
        QJsonObject row;
        for(const auto entry:world["places"].toArray())if(entry.toObject()["slot"]==args["slot"])row=entry.toObject();
        if(!uuid(row["id"]) || !uuid(world["bazaar_id"])){endMarket(409,error("place_changed"));return;}
        marketIntent_=args;marketIntent_["player_id"]=player_;marketIntent_["place_id"]=row["id"];marketIntent_["bazaar_id"]=world["bazaar_id"];
        const auto slot=QString::number(args["slot"].toInt()),price=QString::number(args["price"].toInteger());
        if(action=="rent") {
            if(!row["tenant_id"].isNull() || world["owner_id"]==player_ || row["weekly_price"]!=args["price"] || row["revision"]!=args["revision"] || world["seller_price"]!=args["seller_price"]){
                endMarket(409,error("place_changed"));return;
            }
            bazaarRead("bazaar.sellers",{},[this,generation,slot,price](int status,QJsonObject offers){
                if(generation!=marketGeneration_)return;
                bool found=false;
                for(const auto offer:offers["items"].toArray())if(offer.toObject()["id"]==marketIntent_["species"] && offer.toObject()["price"]==marketIntent_["seller_price"])found=true;
                if(status!=200 || !found){endMarket(409,error("offer_changed"));return;}
                static const QHash<QString,QString> names={{"Casual_Female","Traveller"},{"Casual_Male","Wayfarer"},{"Chef_Female","Chef"},{"Kimono_Female","Tailor"},{"OldClassy_Male","Gentleman"}};
                const auto species=marketIntent_["species"].toString();
                const auto summary=QString("Stall %1 for 7 days: %2 Sparks. %3 for this rental: %4 Sparks. Total: %5 Sparks.")
                    .arg(slot,price,names.value(species,species)).arg(marketIntent_["seller_price"].toInteger()).arg(marketIntent_["price"].toInteger()+marketIntent_["seller_price"].toInteger());
                marketIntent_["summary"]=summary;marketView_={{"text",summary},{"ready",true}};emit changed();
            });
        } else if(action=="list") {
            if(row["tenant_id"]!=player_ || !uuid(row["rental_id"]) || !row["species"].isString()){endMarket(409,error("seller_required"));return;}
            marketIntent_["rental_id"]=row["rental_id"];
            marketView_={{"text","Choose an item from your profile for stall "+slot+" at "+price+" Sparks."},{"picker",true}};
            moreMarketItems();
        } else {
            const QString path="/v1/bazaar-places/"+row["id"].toString()+"/listings?listing_id="+args["listing_id"].toString();
            request("GET",path,{},[this,generation,slot,price](int status,QJsonObject result){
                if(generation!=marketGeneration_)return;
                QJsonObject item;
                for(const auto value:result["items"].toArray())if(value.toObject()["id"]==marketIntent_["listing_id"])item=value.toObject();
                if(status!=200 || result["player_id"]!=player_ || item["seller_id"]==player_ || item["price"]!=marketIntent_["price"] || item["revision"]!=marketIntent_["revision"] || !uuid(item["item_id"])){
                    endMarket(409,error("listing_changed"));return;
                }
                marketIntent_["item_id"]=item["item_id"];
                const auto summary=QString("Buy %1 from stall %2 for %3 Sparks?").arg(item["presentation"].toObject()["title"].toString(),slot,price);
                marketIntent_["summary"]=summary;marketView_={{"text",summary},{"ready",true}};emit changed();
            },access_);
        }
    });
}

void BackendAccount::moreMarketItems() {
    if(marketView_["picker"]!=true || marketView_["loading"]==true)return;
    const auto before=marketView_["next"].toString();
    const auto generation=marketGeneration_;
    marketView_["loading"]=true;emit changed();
    readInventory(before,before.isEmpty()?QString():marketView_["revision"].toString(),[this,generation](int status,QJsonObject data){
        if(generation!=marketGeneration_)return;
        if(status!=200 || data["player_id"]!=player_){endMarket(409,error("inventory_changed"));return;}
        QJsonArray items;
        for(const auto v:data["items"].toArray()){
            const auto row=v.toObject();
            const auto info=row["presentation"].toObject();
            if((marketIntent_["action"]=="inventory" || row["state"]=="stored") && uuid(row["id"]))
                items.append(QJsonObject{{"id",row["id"]},{"title",info["title"]},{"game",info["game"]},{"state",row["state"]}});
        }
        marketView_["items"]=items;marketView_["next"]=data["next"];marketView_["revision"]=data["revision"];marketView_["loading"]=false;emit changed();
    });
}

void BackendAccount::chooseMarketItem(int index) {
    const auto items=marketView_["items"].toArray();
    if(marketView_["picker"]!=true || marketView_["loading"]==true || index<0 || index>=items.size())return;
    const auto item=items[index].toObject();
    if(marketIntent_["action"]=="inventory"){
        marketView_={{"text",QString("%1 · %2 · %3").arg(item["title"].toString(),item["game"].toString(),item["state"].toString())},{"inventory",true}};
        emit changed();return;
    }
    const auto summary=QString("List %1 at stall %2 for %3 Sparks?").arg(item["title"].toString()).arg(marketIntent_["slot"].toInt()).arg(marketIntent_["price"].toInteger());
    marketIntent_["item_id"]=item["id"];marketIntent_["summary"]=summary;
    marketView_={{"text",summary},{"ready",true}};emit changed();
}

void BackendAccount::answerMarketReview(bool confirm) {
    if(!marketReply_ || marketSending_)return;
    if(marketIntent_["action"]=="inventory"){endMarket(200,{{"viewed",true}});return;}
    if(!confirm){endMarket(409,error("review_cancelled"));return;}
    if(marketView_["ready"]!=true || marketIntent_["player_id"]!=player_)return;
    if(marketPending_.isEmpty()) {
        marketIntent_["operation_id"]=QUuid::createUuid().toString(QUuid::WithoutBraces);
        marketPending_=marketIntent_;
        if(!saveCommerce()){marketPending_={};endMarket(503,error("recovery_unavailable"));return;}
    }
    submitMarket();
}

void BackendAccount::submitMarket() {
    const auto p=marketPending_;
    const auto op=p["operation_id"];
    if(p["player_id"]!=player_ || !uuid(op) || !money(p["price"])){endMarket(422,error("invalid_pending_checkout"));return;}
    QString path;QJsonObject body{{"operation_id",op}};
    if(p["action"]=="rent" && uuid(p["place_id"]) && uuid(p["bazaar_id"])){
        path="/v1/bazaars/"+p["bazaar_id"].toString()+"/places/"+p["place_id"].toString()+"/staffed-rental";
        body["revision"]=p["revision"];body["expected_price"]=p["price"];body["species"]=p["species"];body["seller_price"]=p["seller_price"];
    }else if(p["action"]=="list" && uuid(p["rental_id"]) && uuid(p["item_id"])){
        path="/v1/me/bazaar-rentals/"+p["rental_id"].toString()+"/listings";body["item_id"]=p["item_id"];body["price"]=p["price"];
    }else if(p["action"]=="buy" && uuid(p["listing_id"])){
        path="/v1/bazaar-listings/"+p["listing_id"].toString()+"/buy";body["revision"]=p["revision"];body["expected_price"]=p["price"];
    }else{endMarket(422,error("invalid_pending_checkout"));return;}
    marketSending_=true;marketView_={{"text","Waiting for the market receipt…"}};emit changed();
    request("POST",path,body,[this,p](int status,QJsonObject result){
        marketSending_=false;
        const bool paid=status==200 && matchesReceipt(p,result);
        const bool refused=(status==404 || status==409 || status==422) && !result["code"].toString().isEmpty();
        if(paid || refused){
            marketPending_={};
            if(!saveCommerce()){marketPending_=p;endMarket(503,error("checkout_pending"));return;}
            if(paid){endMarket(200,{{"confirmed",true},{"action",p["action"]}});refreshProgression(false);}
            else endMarket(status,error(result["code"].toString()));
        }else endMarket(503,error("checkout_pending"));
    },access_);
}
}
