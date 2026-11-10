#pragma once
#include "features/accounts/BackendAccount.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QDateTime>
#include <QUrlQuery>
#include <QUrl>
#include <memory>

namespace trainer {
// In-memory transport only. Never connects to a service or spends real Sparks.
struct BazaarCommerceFixture : std::enable_shared_from_this<BazaarCommerceFixture> {
    const QString player="11111111-1111-4111-8111-111111111111";
    const QString place="55555555-5555-4555-8555-555555555555";
    const QString visitor="22222222-2222-4222-8222-222222222222";
    bool blocked=false;int blockWrites=0;
    QHash<QString,QByteArray> commerce;
    QJsonObject purchaseBody, inventory;
    int charges=0, edits=0;
    bool failStorage=false, loseResponse=false, conflict=false, badReceipt=false;
    BazaarCommerceFixture() {
        inventory={{"player_id",player},{"revision","1"},{"items",QJsonArray{}},{"catalogue",QJsonArray{}},{"equipped",QJsonValue()},
            {"bazaar_license",false},{"bazaar",QJsonValue()},{"bazaar_offer",QJsonObject{{"id","bazaar.personal"},{"purpose","bazaar_space"},{"kind","permanent_license"},
            {"revision","1"},{"price",5000},{"title","Personal Bazaar"}}}};
    }
    BackendAccount::Services services() {
        auto self=shared_from_this();BackendAccount::Services result;
        result.read=[](QString,auto done){done(true,QJsonDocument(QJsonObject{{"refresh_token",QString(43,'r')}}).toJson());};
        result.write=[](QString,QByteArray,auto done){done(true);};
        result.openBrowser=[](QUrl){return true;};
        result.readCommerce=[self](QString key){return self->commerce.value(key);};
        result.writeCommerce=[self](QString key,QByteArray bytes){if(self->failStorage)return false;self->commerce[key]=bytes;return true;};
        result.request=[self](QByteArray method,QString path,QJsonObject body,QByteArray,BackendAccount::Reply done){
            if(path=="/v1/auth/refresh") {done(200,{{"player_id",self->player},{"session_id","33333333-3333-4333-8333-333333333333"},
                {"fluxer_subject","12345"},{"access_token",QString(43,'a')},{"refresh_token",QString(43,'r')},
                {"expires_at",QDateTime::currentDateTimeUtc().addSecs(900).toString(Qt::ISODateWithMs)}});return;}
            if(path=="/v1/me/progression") {done(200,{{"player_id",self->player},{"balance",10000-5000*self->charges},{"revision",QString::number(1+self->charges)},
                {"history",QJsonArray{}},{"mastery",QJsonObject{{"xp",2000},{"level",5},{"level_xp",0},{"next_level_xp",700}}},
                {"checked_at",QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)}});return;}
            if(path=="/v1/me/inventory"||path.startsWith("/v1/me/purchases/")){done(200,self->inventory);return;}
            if(path=="/v1/me/purchases"&&method=="POST") {
                self->purchaseBody=body;
                if(!self->inventory["bazaar_license"].toBool())++self->charges;
                self->inventory["bazaar_license"]=true;self->inventory["revision"]="2";
                auto receipt=body;receipt["id"]="44444444-4444-4444-8444-444444444444";receipt["player_id"]=self->player;
                receipt["price"]=receipt.take("expected_price");receipt["details"]=QJsonObject{};
                if(self->badReceipt)receipt["details"]=QJsonObject{{"name","Wrong payload"}};
                self->inventory["receipt"]=receipt;done(self->loseResponse?0:200,self->loseResponse?QJsonObject{}:self->inventory);return;
            }
            if(path=="/v1/profiles/"+self->visitor){done(200,{{"player_id",self->visitor},{"display_name","Visiting Player"},{"subject","22222"},{"avatar",QJsonValue()},{"visibility",QJsonObject{}}});return;}
            if(path.startsWith("/v1/me/bazaars/"+self->place+"/access?")) {
                QJsonArray rows;if(self->blocked)rows.append(QJsonObject{{"player_id",self->visitor},{"name","Visiting Player"}});
                const auto target=QUrlQuery(QUrl(path)).queryItemValue("target");
                done(200,{{"player_id",self->player},{"bazaar_license",true},{"bazaar",self->inventory["bazaar"]},{"blocks",rows},{"next",QJsonValue()},
                    {"target",target.isEmpty()?QJsonValue():QJsonValue(QJsonObject{{"player_id",self->visitor},{"name","Visiting Player"},{"blocked",self->blocked}})},{"live_moderation",false}});return;
            }
            if(path=="/v1/me/bazaars/"+self->place+"/blocks/"+self->visitor) {
                auto row=self->inventory["bazaar"].toObject();if(body["revision"]!=row["revision"]){done(409,{{"code","bazaar_changed"}});return;}
                self->blocked=body["blocked"].toBool();++self->blockWrites;row["revision"]=QString::number(row["revision"].toString().toInt()+1);self->inventory["bazaar"]=row;
                done(200,{{"player_id",self->player},{"bazaar_license",true},{"bazaar",row},{"target",QJsonObject{{"player_id",self->visitor},{"blocked",self->blocked}}},{"live_moderation",false}});return;
            }
            if(path=="/v1/me/bazaars"&&method=="POST") {
                if(!self->inventory["bazaar_license"].toBool()){done(409,{{"code","bazaar_license_required"}});return;}
                if(self->inventory["bazaar"].isNull()) {
                    auto owned=body;owned["id"]=self->place;owned["owner_id"]=self->player;owned["offer_id"]="bazaar.personal";owned["revision"]="1";
                    self->inventory["bazaar"]=owned;
                }
                done(200,{{"player_id",self->player},{"bazaar_license",true},{"bazaar",self->inventory["bazaar"]}});return;
            }
            if(path.startsWith("/v1/bazaars?")) {
                QJsonArray rows;auto row=self->inventory["bazaar"].toObject();
                if(!row.isEmpty()){row["owner_name"]="Developer";row["owned"]=true;row["visitors"]=QJsonValue();row["join_available"]=false;rows.append(row);}
                done(200,{{"player_id",self->player},{"items",rows},{"next",QJsonValue()},{"join_available",false}});return;
            }
            if(path=="/v1/me/bazaars/"+self->place) {
                if(self->conflict){done(409,{{"code","bazaar_changed"}});return;}
                ++self->edits;auto row=self->inventory["bazaar"].toObject();for(auto it=body.begin();it!=body.end();++it)row[it.key()]=it.value();
                row["revision"]=QString::number(body["revision"].toString().toInt()+1);self->inventory["bazaar"]=row;
                done(200,{{"player_id",self->player},{"bazaar",row}});return;
            }
            done(503,{});
        };
        return result;
    }
    void install(BackendAccount& backend){backend.configure({});backend.setServices(services());backend.configure("bazaar-forms-test");}
};
}
