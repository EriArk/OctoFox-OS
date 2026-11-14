#include "BackendAccount.h"
#include <QUrlQuery>
#include <QUuid>
#include <QDateTime>
#include <cmath>

namespace trainer {
namespace {
bool id(const QJsonValue& v){return v.isString()&&v.toString().size()==36&&!QUuid(v.toString()).isNull();}
bool integer(const QJsonValue& v){return v.isDouble()&&std::isfinite(v.toDouble())&&v.toDouble()>0&&v.toDouble()<=2147483647&&std::floor(v.toDouble())==v.toDouble();}
bool revision(const QJsonValue& v){bool ok=false;const auto n=v.toString().toULongLong(&ok);return ok&&n>0;}
bool text(const QJsonValue& v,int max,bool required=false){if(!v.isString()||v.toString().size()>max||(required&&v.toString().trimmed().isEmpty()))return false;for(auto c:v.toString())if(c.unicode()<32||c.unicode()==127)return false;return true;}
}
bool BackendAccount::validBazaarDetails(const QJsonObject& row) const {
    return row.size()==4+row.contains("cover")+row.contains("badge")
        &&(!row.contains("cover")||QStringList{"market","grove","harbor"}.contains(row["cover"].toString()))
        &&(!row.contains("badge")||QStringList{"shop","community","companion","trophy","guide"}.contains(row["badge"].toString()))
        &&text(row["name"],48,true)&&text(row["description"],280)&&row["listed"].isBool()
        &&QStringList{"open","closed"}.contains(row["access"].toString());
}
bool BackendAccount::validBazaar(const QJsonObject& value) const {
    // Neither a permanent right nor a created space can disappear in a delayed inventory reply.
    if(shopSnapshot_["player_id"]==value["player_id"]) {
        if(shopSnapshot_["bazaar_license"].toBool()&&!value["bazaar_license"].toBool())return false;
        if(!shopSnapshot_["bazaar"].toObject().isEmpty()&&value["bazaar"].toObject().isEmpty())return false;
    }
    if(value.contains("bazaar_license")&&!value["bazaar_license"].isBool())return false;
    for(const auto key:{"bazaar_offer","bazaar_stall_offer"})if(value.contains(key)&&!value[key].isNull()) {
        const auto offer=value[key].toObject();const bool stall=QString(key)=="bazaar_stall_offer";
        if(offer["id"]!=(stall?"bazaar.stall":"bazaar.personal")||offer["purpose"]!=(stall?"bazaar_stall":"bazaar_space")||offer["kind"]!="permanent_license"
            ||!integer(offer["price"])||!revision(offer["revision"])||!text(offer["title"],128,true))return false;
    }
    if(value.contains("bazaar")&&!value["bazaar"].isNull()) {
        const auto row=value["bazaar"].toObject();
        const auto current=shopSnapshot_["bazaar"].toObject();
        if(!current.isEmpty()&&current["id"]==row["id"]&&current["owner_id"]==row["owner_id"]
            &&row["revision"].toString().toULongLong()<current["revision"].toString().toULongLong())return false;
        if(!id(row["id"])||row["owner_id"]!=value["player_id"]||row["offer_id"]!="bazaar.personal"||!revision(row["revision"])
            ||!validBazaarDetails({{"name",row["name"]},{"description",row["description"]},{"listed",row["listed"]},{"access",row["access"]},{"cover",row["cover"].toString("market")},{"badge",row["badge"].toString("shop")}}))return false;
    }
    return true;
}
QVariantMap BackendAccount::bazaarAccount() const {
    const auto player=player_.isEmpty()?cachedIdentity_["player_id"].toString():player_;
    const bool same=!player.isEmpty()&&shopSnapshot_["player_id"]==player;
    return {{"paymentsAvailable",services_.bazaarDevelopmentPayments},{"playerId",player},{"connected",state_=="connected"&&!player_.isEmpty()},
        {"licensed",same&&shopSnapshot_["bazaar_license"].toBool()},
        {"owned",same?shopSnapshot_["bazaar"].toObject().toVariantMap():QVariantMap{}},
        {"stallOffer",same?shopSnapshot_["bazaar_stall_offer"].toObject().toVariantMap():QVariantMap{}},
        {"stallPending",shopPending_["offer_id"]=="bazaar.stall"&&shopPending_["player_id"]==player_},
        {"stallReview",shopReview_["id"]=="bazaar.stall"?shopReview_.toVariantMap():QVariantMap{}},
        {"offer",same?shopSnapshot_["bazaar_offer"].toObject().toVariantMap():QVariantMap{}},
        {"busy",shopBusy_},{"stale",shopStale_},{"status",shopStatus_},
        {"rentalPending",shopPending_["kind"]=="bazaar.rent"&&shopPending_["player_id"]==player_},{"pending",!shopPending_.isEmpty()},{"bazaarPending",shopPending_["offer_id"]=="bazaar.personal"&&shopPending_["player_id"]==player_},
        {"review",shopReview_["id"]=="bazaar.personal"?shopReview_.toVariantMap():QVariantMap{}}};
}
void BackendAccount::reviewBazaarPurchase(bool stall) {
    if(!services_.bazaarDevelopmentPayments){shopStatus_="Bazaar is under development. Purchases are disabled.";emit changed();return;}
    if(shopBusy_||state_!="connected"||shopStale_||!shopPending_.isEmpty())return;
    if(stall?shopSnapshot_["bazaar"].toObject().isEmpty():(shopSnapshot_["bazaar_license"].toBool()||!shopSnapshot_["bazaar"].toObject().isEmpty()))return;
    const auto offer=shopSnapshot_[stall?"bazaar_stall_offer":"bazaar_offer"].toObject();
    if(offer.isEmpty())return;
    shopReview_=offer;emit changed();
}
void BackendAccount::resolveBazaarPurchase(){if(shopPending_.value("offer_id")=="bazaar.personal"||shopPending_.value("offer_id")=="bazaar.stall"||shopPending_.value("kind")=="bazaar.rent")recoverPurchase(true);}
// Read-only SDK projection. No access/refresh token, arbitrary path or spending
// method crosses this boundary; a self-declared app ID is not publisher trust.
void BackendAccount::bazaarRead(const QString& method,QJsonObject args,Reply done) {
    if(state_!="connected"||player_.isEmpty()){done(401,{{"code","sign_in_required"}});return;}
    QString path;
    if(method=="bazaar.world"&&args.isEmpty())path="/v1/bazaar-worlds/festival";
    else if(method=="bazaar.costumes"&&args.isEmpty())path="/v1/bazaar-costumes";
    else if(method=="bazaar.sellers"&&args.isEmpty())path="/v1/bazaar-sellers";
    else if(method=="bazaar.listings"||method=="bazaar.own_listings") {
        if(method=="bazaar.listings") {
            const auto place=args.take("place_id");if(!id(place)){done(422,{{"code","invalid_place"}});return;}
            path="/v1/bazaar-places/"+place.toString()+"/listings";
        } else path="/v1/me/bazaar-listings";
        if(args.contains("after")) {
            const auto after=args.take("after");if(!id(after)){done(422,{{"code","invalid_page"}});return;}
            path+="?after="+after.toString();
        }
        if(!args.isEmpty()){done(422,{{"code","unsupported_bazaar_read"}});return;}
    }
    else {done(422,{{"code","unsupported_bazaar_read"}});return;}
    const auto player=player_;
    request("GET",path,{},[this,player,done=std::move(done)](int status,QJsonObject result){
        if(player!=player_||state_!="connected")return;
        if(status==200&&(result["player_id"]!=player||QJsonDocument(result).toJson(QJsonDocument::Compact).size()>60000)) {
            done(502,{{"code","invalid_bazaar_snapshot"}});return;
        }
        done(status,std::move(result));
    },access_);
}
void BackendAccount::bazaarRequest(const QString& action,QJsonObject args,Reply done) {
    if(state_!="connected"||player_.isEmpty()){done(401,{{"code","sign_in_required"}});return;}
    if(action=="directory") {
        QUrlQuery query;query.addQueryItem("q",args["q"].toString().left(64));
        const auto after=args["after"].toString();if(!after.isEmpty()){if(!id(after)){done(422,{});return;}query.addQueryItem("after",after);}
        if(args.contains("favorites")) {
            QStringList ids;for(const auto value:args["favorites"].toArray()){if(!id(value)||ids.size()>=100){done(422,{});return;}ids.append(value.toString());}
            query.addQueryItem("favorites",ids.join(','));
        }
        request("GET","/v1/bazaars?"+query.toString(QUrl::FullyEncoded),{},std::move(done),access_);return;
    }
    if(action=="places"||action=="place-price") {
        const auto bazaar=args.take("id");if(!id(bazaar)){done(422,{});return;}
        QString path="/v1/bazaars/"+bazaar.toString()+"/places";
        if(action=="places") {
            QUrlQuery query;if(args.contains("after")){if(!id(args["after"])){done(422,{});return;}query.addQueryItem("after",args["after"].toString());}
            if(args.size()>1){done(422,{});return;}
            request("GET",path+"?"+query.toString(QUrl::FullyEncoded),{},std::move(done),access_);
        } else {
            const auto place=args.take("place_id");
            if(!id(place)||!revision(args["revision"])||!integer(args["weekly_price"])||args.size()!=2){done(422,{});return;}
            request("PUT","/v1/me/bazaars/"+bazaar.toString()+"/places/"+place.toString(),args,std::move(done),access_);
        }
        return;
    }
    if(action=="update"||action=="create"||action=="access"||action=="block") {
        const auto bazaar=args.take("id").toString();const auto version=args.take("revision");
        QByteArray method="PUT";QString path="/v1/me/bazaars/"+bazaar;
        if(action=="access") {
            if(!id(bazaar)){done(422,{});return;}
            QUrlQuery query;
            for(const auto key:{"target","after"})if(args.contains(key)){if(!id(args[key])){done(422,{});return;}query.addQueryItem(key,args[key].toString());}
            if(args.size()>2){done(422,{});return;}
            path+="/access?"+query.toString(QUrl::FullyEncoded);method="GET";args={};
        } else if(action=="block") {
            const auto target=args.take("target");
            if(!id(bazaar)||!id(target)||!revision(version)||args.size()!=1||!args["blocked"].isBool()){done(422,{});return;}
            path+="/blocks/"+target.toString();args["revision"]=version;
        } else {
            if(!validBazaarDetails(args)||(action=="update"&&(!id(bazaar)||!revision(version)))){done(422,{});return;}
            if(action=="update")args["revision"]=version;
            else {method="POST";path="/v1/me/bazaars";}
        }
        request(method,path,args,[this,done=std::move(done)](int status,QJsonObject value){
            if(status==200)value["bazaar_license"]=true;
            if(status==200&&value["player_id"]==player_&&validBazaar(value)&&!value["bazaar"].toObject().isEmpty()) {
                shopSnapshot_["bazaar"]=value["bazaar"];shopSnapshot_["bazaar_license"]=true;saveCommerce();emit changed();
            } else if(status==200){status=502;value={};}
            done(status,std::move(value));
        },access_);return;
    }
    done(422,{});
}
void BackendAccount::rentBazaarPlace(QJsonObject place,QString bazaar) {
    if(!services_.bazaarDevelopmentPayments){shopStatus_="Bazaar is under development. Rentals are disabled.";emit changed();return;}
    if(shopBusy_||state_!="connected"||!shopPending_.isEmpty()||!id(bazaar)||!id(place["id"])
        ||!revision(place["revision"])||!integer(place["weekly_price"])||place["rentable"]!=true)return;
    shopPending_={{"kind","bazaar.rent"},{"player_id",player_},{"operation_id",QUuid::createUuid().toString(QUuid::WithoutBraces)},
        {"bazaar_id",bazaar},{"place_id",place["id"]},{"revision",place["revision"]},{"expected_price",place["weekly_price"]}};
    if(!saveCommerce()){shopPending_={};shopStatus_="Could not save payment recovery data. Nothing was sent or charged.";emit changed();return;}
    recoverPurchase(true);
}
void BackendAccount::finishRental(int status,QJsonObject result) {
    shopBusy_=false;const auto receipt=result["receipt"].toObject();
    const auto started=QDateTime::fromString(receipt["started_at"].toString(),Qt::ISODateWithMs);
    const auto expires=QDateTime::fromString(receipt["expires_at"].toString(),Qt::ISODateWithMs);
    const bool exact=result["player_id"]==player_&&receipt["tenant_id"]==player_&&id(receipt["id"])&&id(receipt["owner_id"])
        &&receipt["operation_id"]==shopPending_["operation_id"]&&receipt["place_id"]==shopPending_["place_id"]
        &&receipt["price"]==shopPending_["expected_price"]
        &&QString::number(receipt["offer_revision"].toInteger())==shopPending_["revision"].toString()
        &&started.isValid()&&expires.isValid()&&started.secsTo(expires)==604800;
    const bool declined=(status==404&&QStringList{"bazaar_not_found","place_not_found"}.contains(result["code"].toString()))||(status==409&&QStringList{"place_changed","place_occupied","insufficient_sparks","own_place","bazaar_access_denied","bazaar_under_development"}.contains(result["code"].toString()));
    if((status==200&&exact)||declined) {
        const auto pending=shopPending_;shopPending_={};if(!saveCommerce())shopPending_=pending;
        shopStatus_=status==200?"Place rented until "+expires.toLocalTime().toString("dd MMM yyyy HH:mm")+". Payment sent to its owner.":
            result["code"]=="insufficient_sparks"?"Not enough Sparks. No charge was made.":"Place or access changed. No charge was made. Refresh and review again.";
        refreshProgression(false);
    } else shopStatus_="Rental payment not yet confirmed. Resolve it to check or retry the same payment.";
    emit changed();
}

}
