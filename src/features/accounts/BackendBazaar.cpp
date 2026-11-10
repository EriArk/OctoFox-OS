#include "BackendAccount.h"
#include <QUrlQuery>
#include <QUuid>
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
    if(value.contains("bazaar_offer")&&!value["bazaar_offer"].isNull()) {
        const auto offer=value["bazaar_offer"].toObject();
        if(offer["id"]!="bazaar.personal"||offer["purpose"]!="bazaar_space"||offer["kind"]!="permanent_license"
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
    return {{"playerId",player},{"connected",state_=="connected"&&!player_.isEmpty()},
        {"licensed",same&&shopSnapshot_["bazaar_license"].toBool()},
        {"owned",same?shopSnapshot_["bazaar"].toObject().toVariantMap():QVariantMap{}},
        {"offer",same?shopSnapshot_["bazaar_offer"].toObject().toVariantMap():QVariantMap{}},
        {"busy",shopBusy_},{"stale",shopStale_},{"status",shopStatus_},
        {"pending",!shopPending_.isEmpty()},{"bazaarPending",shopPending_["offer_id"]=="bazaar.personal"&&shopPending_["player_id"]==player_},
        {"review",shopReview_["id"]=="bazaar.personal"?shopReview_.toVariantMap():QVariantMap{}}};
}
void BackendAccount::reviewBazaarPurchase() {
    if(shopBusy_||state_!="connected"||shopStale_||!shopPending_.isEmpty()||shopSnapshot_["bazaar_license"].toBool()||!shopSnapshot_["bazaar"].toObject().isEmpty())return;
    const auto offer=shopSnapshot_["bazaar_offer"].toObject();
    if(offer.isEmpty())return;
    shopReview_=offer;emit changed();
}
void BackendAccount::resolveBazaarPurchase(){if(shopPending_["offer_id"]=="bazaar.personal")recoverPurchase(true);}
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
}
