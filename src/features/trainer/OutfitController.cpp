#include "OutfitController.h"
#include "../../../sdk/qt/AvatarResource.h"
#include <QBuffer>
#include "TrainerController.h"
#include "AvatarAssets.h"
#include "features/accounts/BackendAccount.h"
#include <QtConcurrent>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QCryptographicHash>
#include <QTimer>
#include <QQuaternion>
#include <QMatrix4x4>
#include <QQmlListReference>
#include <QJsonDocument>
#include <QJsonArray>
#include <QtEndian>
#include <QUuid>
#include <cstring>
namespace trainer {
namespace {
const QStringList fields{"headwear","top","bottom","socks","shoes","top"};
const QStringList labels{"Headwear","Tops","Bottoms","Socks","Shoes","Outfits"};
QString title(const QString& id) {
    static const QMap<QString,QString> names{{"tank","Sports tank"},{"base-shorts","Basic shorts"},{"none","None"},{"sandals","Sandals"},
        {"polo-short-sleeve","Polo"},{"polo-sleeveless","Sleeveless polo"},{"golf-shorts","Golf shorts"},{"pleated-skirt","Pleated skirt"},
        {"ankle-socks","Ankle socks"},{"crew-socks","Long socks"},{"golf-shoes-classic","Classic shoes"},{"golf-shoes-sport","Sport shoes"},
        {"golf-cap","Cap"},{"golf-visor","Visor"},{"swept","Side swept"},{"ponytail","Ponytail"},{"crop","Short crop"},{"bob","Bob"},
        {"sundress","Pleated sundress"},{"everyday-tee","Everyday T-shirt"},{"denim-breeches","Men’s denim breeches"},{"denim-breeches-womens","Women’s denim breeches"},{"canvas-shoes","Canvas shoes"},
        {"racing-suit","Racing suit"},{"rose-racing-suit","Rose racing suit"},{"racing-helmet","Racing helmet"},{"rose-racing-helmet","Rose helmet"},
        {"racing-boots","Racing boots"},{"rose-racing-boots","Rose racing boots"}};
    static const QMap<QString,QString> ship{{"traveller.top","Trail cloak"},{"traveller.bottom","Trail trousers"},{"traveller.boots","Ranger boots"},{"traveller.hat","Feather cap"},
        {"mage.top","Starweave coat"},{"mage.bottom","Indigo leggings"},{"mage.boots","Rune boots"},{"mage.hat","Astral hat"},
        {"merchant.top","Apron & vest"},{"merchant.bottom","Market breeches"},{"merchant.boots","Guild shoes"},{"merchant.hat","Market beret"}};
    if(ship.contains(id))return ship[id];
    if(names.contains(id))return names[id];
    auto text=id;text.replace("-feminine"," - lashes");text.replace("-base","");if(!text.isEmpty())text[0]=text[0].toUpper();return text;
}
}
OutfitController::OutfitController(BackendAccount& account,TrainerController& trainer,QObject* parent)
    :QObject(parent),account_(account),trainer_(trainer) {
    connect(&account_,&BackendAccount::changed,this,[this]{
        if(!open_)return;const auto player=account_.snapshot()["player_id"].toString();
        if(!player_.isEmpty()&&!player.isEmpty()&&player_!=player){close();emit backRequested();return;}
        index_=qBound(0,index_,int(rows().size())-1);emit changed();
    });
    connect(&trainer_,&TrainerController::changed,this,[this]{
        if(open_&&trainer_.profile()["id"].toString()!=owner_){close();emit backRequested();return;}
        if(open_||livePending_){
            if(!trainer_.saving()&&!trainer_.error().isEmpty()){status_=trainer_.error();liveFailed_=true;}
            QTimer::singleShot(0,this,[this]{saveLive();});emit changed();
        }
    });
    connect(&job_,&QFutureWatcher<QJsonObject>::finished,this,[this]{
        if(jobGeneration_!=generation_){if(open_)startPreview();return;}
        const auto result=job_.result();previewError_=result["error"].toString();
        if(previewError_.isEmpty())previewUrl_=QUrl::fromLocalFile(result["preview"].toString()).toString();
        const auto files=QDir(cache_.path()).entryInfoList({"*.tav","*.glb"},QDir::Files,QDir::Time);
        for(int i=4;i<files.size();++i)QFile::remove(files[i].absoluteFilePath());
        emit changed();
    });
}
OutfitController::~OutfitController(){job_.waitForFinished();}
int OutfitController::posePreview(QObject* loader,qreal amount){
    if(!loader)return 0;
    const QMap<QString,QVector3D> poses{{"head",{12,12,0}},{"neck",{3,0,0}},
        {"upper_arm.L",{0,0,-12}},{"upper_arm.R",{0,0,12}},
        {"forearm.L",{0,-16,0}},{"forearm.R",{0,16,0}}};
    if(loader->property("pose").isValid()) {
        QVariantMap pose;for(auto it=poses.begin();it!=poses.end();++it)pose[it.key()]=QVariant::fromValue(it.value()*amount);
        loader->setProperty("pose",pose);return poses.size();
    }
    const auto source=loader->property("source").toUrl();
    // RuntimeLoader does not retain glTF node names and Assimp may reduce each
    // mesh's joint list. Match bind matrices, never guessed QObject/list indices.
    if(loader->property("wardrobeBoundSource").toUrl()!=source) {
        QBuffer file;file.setData(AvatarResource::read(source.toLocalFile()));
        if(!source.isLocalFile()||!file.open(QIODevice::ReadOnly))return 0;
        const auto header=file.read(20);
        if(header.size()!=20||qFromLittleEndian<quint32>(header.constData())!=0x46546c67)return 0;
        const auto jsonSize=qFromLittleEndian<quint32>(header.constData()+12);
        if(jsonSize>8*1024*1024)return 0;
        const auto gltf=QJsonDocument::fromJson(file.read(jsonSize)).object();
        const auto nodes=gltf["nodes"].toArray(),accessors=gltf["accessors"].toArray(),views=gltf["bufferViews"].toArray();
        QList<QPair<QMatrix4x4,QVector3D>> bindings;
        for(const auto entry:gltf["skins"].toArray()) {
            const auto skin=entry.toObject();const auto joints=skin["joints"].toArray();
            const auto accessor=accessors.at(skin["inverseBindMatrices"].toInt()).toObject();
            const auto view=views.at(accessor["bufferView"].toInt()).toObject();
            if(accessor["componentType"]!=5126||accessor["type"]!="MAT4")continue;
            for(int i=0;i<joints.size();++i) {
                const auto name=nodes.at(joints[i].toInt()).toObject()["name"].toString();
                if(!poses.contains(name))continue;
                const qint64 offset=28+qint64(jsonSize)+view["byteOffset"].toInt()+accessor["byteOffset"].toInt()+qint64(i)*view.value("byteStride").toInt(64);
                if(!file.seek(offset))continue;const auto bytes=file.read(64);if(bytes.size()!=64)continue;
                QMatrix4x4 matrix;
                for(int j=0;j<16;++j){const auto bits=qFromLittleEndian<quint32>(bytes.constData()+j*4);float value;std::memcpy(&value,&bits,4);matrix.data()[j]=value;}
                bindings.append({matrix,poses[name]});
            }
        }
        bool bound=false;
        for(auto* skin:loader->findChildren<QObject*>()) {
            if(!skin->property("inverseBindPoses").isValid())continue;
            const auto matrices=skin->property("inverseBindPoses").value<QList<QMatrix4x4>>();
            QQmlListReference joints(skin,"joints");
            for(int i=0;i<qMin(matrices.size(),joints.count());++i)for(const auto& binding:bindings) {
                bool same=true;for(int j=0;j<16;++j)same&=qAbs(matrices[i].constData()[j]-binding.first.constData()[j])<0.0002f;
                auto* node=joints.at(i);if(!same||!node)continue;
                node->setProperty("wardrobePose",QVariant::fromValue(binding.second));bound=true;break;
            }
        }
        if(bound)loader->setProperty("wardrobeBoundSource",source);
    }
    int count=0;
    for(auto* node:loader->findChildren<QObject*>()) {
        if(!node->property("wardrobePose").isValid()||!node->property("rotation").isValid())continue;
        if(!node->property("wardrobeNeutral").isValid())node->setProperty("wardrobeNeutral",node->property("rotation"));
        const auto neutral=node->property("wardrobeNeutral").value<QQuaternion>();
        node->setProperty("rotation",QVariant::fromValue(neutral*QQuaternion::fromEulerAngles(node->property("wardrobePose").value<QVector3D>()*float(amount))));
        ++count;
    }
    return count;
}
QVariantList OutfitController::rows() const {
    QVariantList result{QVariantMap{{"id","current"},{"name",account_.wardrobeState().value("freeName").toString("Everyday")},{"current",true}}};
    for(const auto item:account_.outfits()["items"].toList()) {
        auto row=item.toMap();const auto saved=row["saved"].toMap();row["name"]=saved.isEmpty()?"Set "+row["slot_number"].toString():saved["name"];result.append(row);
    }
    const auto next=account_.outfits()["next"].toMap();if(!next.isEmpty()){auto row=next;row["name"]="+";row["buy"]=true;result.append(row);}return result;
}
QVariantMap OutfitController::selected() const {return rows().value(index_).toMap();}
void OutfitController::refreshGarments(std::function<void()> done) {
    const auto player=account_.snapshot()["player_id"].toString();
    if(player!=garmentOwner_ || !account_.inventoryConnected()){garments_={};garmentOwner_.clear();}
    const auto generation=++garmentGeneration_;
    if(account_.inventoryConnected())readGarments(player,{}, {},generation,std::move(done));
    else if(done)done();
}
void OutfitController::readGarments(QString player,QString after,QJsonArray rows,quint64 generation,std::function<void()> done) {
    QJsonObject args;
    if(!after.isEmpty())args["after"]=after;
    account_.workshopRequest("workshop.garments",args,[this,player,after,rows,generation,done=std::move(done)](int status,QJsonObject reply) mutable {
        if(generation!=garmentGeneration_ || player!=account_.snapshot()["player_id"].toString()){if(done)done();return;}
        if(status!=200 || reply["player_id"]!=player){garments_={};garmentOwner_.clear();emit changed();if(done)done();return;}
        for(const auto& item:reply["items"].toArray())rows.append(item);
        const auto next=reply["next"].toString();
        if(!next.isEmpty() && next>after){readGarments(player,next,rows,generation,std::move(done));return;}
        garments_=rows;garmentOwner_=player;
        if(open_ && player==player_ && owner_==trainer_.profile()["id"].toString()){
            auto look=appearance_;
            const auto equipment=look["equipment"].toObject();
            for(auto slot=equipment.begin();slot!=equipment.end();++slot){
                const auto id=slot.value().toObject()["id"];
                const auto match=std::find_if(rows.constBegin(),rows.constEnd(),[&](QJsonValue piece){return piece.toObject()["id"]==id;});
                if(match!=rows.constEnd())look=AvatarAssets::withGarment(look,(*match).toObject());
            }
            if(look!=appearance_ && AvatarAssets::valid(look))commit(look);
        }
        emit changed();if(done)done();
    });
}
QJsonArray OutfitController::ownedGarments() const {
    return account_.inventoryConnected() && garmentOwner_==account_.snapshot()["player_id"].toString()?garments_:QJsonArray{};
}
QVariantList OutfitController::items() const {
    QVariantList result;for(const auto& id:AvatarAssets::choices(fields[category_])) {
        if(id=="none")continue;
        if(fields[category_]=="top"&&(AvatarAssets::onePiece(id)!=(category_==5)))continue;
        const bool covered=category_==2&&AvatarAssets::onePiece(appearance_["top"].toString());
        result.append(QVariantMap{{"id",id},{"name",title(id)},{"equipped",!covered&&appearance_[fields[category_]]==id},{"thumbnail",QString("qrc:/wardrobe/%1.png").arg(id)}});
    }
    const auto field=fields[category_];
    if(category_!=5)for(const auto item:ownedGarments()){
        const auto piece=item.toObject();const auto sku=piece["sku"].toString();
        if(AvatarAssets::workshopSlot(sku)!=field)continue;
        result.append(QVariantMap{{"id",piece["id"].toString()},{"name",title(sku)},{"garment",piece.toVariantMap()},
            {"equipped",appearance_["equipment"].toObject()[field].toObject()["id"]==piece["id"]},
            {"thumbnail",QString("qrc:/wardrobe/%1.png").arg(sku)}});
    }
    return result;
}
QString OutfitController::colourKey() const {return QStringList{"headwearColor","shirtColor","shortsColor","socksColor","shoesColor","shirtColor"}[category_];}
QStringList OutfitController::dyeChannels() const {
    const auto field=fields[category_];
    if(!appearance_["equipment"].toObject().contains(field))return {};
    const auto sku=appearance_[field].toString();
    if(field=="bottom")return {"primary"};
    if(sku=="merchant.hat")return {"primary","secondary","accent"};
    if(sku=="traveller.hat" || sku=="mage.top" || sku=="mage.hat")return {"primary","trim","accent"};
    return {"primary","secondary","trim","accent"};
}
QStringList OutfitController::unlockedDyes() const {
    if(!account_.inventoryConnected() || paletteOwner_!=account_.snapshot()["player_id"].toString() || palette_.isEmpty())return {};
    QStringList result{"original"};
    for(const auto dye:palette_["palette"].toArray())result.append(dye.toString());
    return result;
}
void OutfitController::loadPalette(){
    const auto player=account_.snapshot()["player_id"].toString();
    if(paletteOwner_!=player){palette_={};paletteOwner_.clear();}
    if(!account_.inventoryConnected())return;
    account_.workshopRequest("workshop.get",{},[this,player](int status,QJsonObject data){
        if(player!=account_.snapshot()["player_id"].toString())return;
        palette_=status==200?data:QJsonObject{};paletteOwner_=player;emit changed();
    });
}
void OutfitController::nextDyeChannel(){
    const auto channels=dyeChannels();if(channels.isEmpty())return;
    dyeChannel_=(dyeChannel_+1)%channels.size();colour_=0;focus_=3;emit changed();
}
void OutfitController::paintGarment(const QString& dye){
    const auto channels=dyeChannels();if(channels.isEmpty() || painting_)return;
    const auto field=fields[category_], channel=channels[dyeChannel_%channels.size()];
    const auto part=appearance_["equipment"].toObject()[field].toObject();
    const auto colors=part["colors"].toObject();
    if(dye==colors[channel].toString("original"))return;
    const auto player=paletteOwner_,owner=owner_;
    const auto sku=appearance_[field].toString();
    painting_=true;
    account_.workshopRequest("workshop.get",{},[this,player,owner,part,field,sku,channel,dye](int status,QJsonObject data){
        if(status!=200 || data["player_id"]!=player || owner!=owner_ || !open_){
            painting_=false;status_="Could not verify the inventory.";emit changed();return;
        }
        QJsonObject args{{"operation_id",QUuid::createUuid().toString(QUuid::WithoutBraces)},{"revision",data["revision"]},
            {"item",part["id"]},{"channel",channel},{"color",dye}};
        account_.workshopRequest("workshop.paint",args,[this,player,owner,field,sku,part,channel,dye](int status,QJsonObject result){
            painting_=false;
            if(player!=account_.snapshot()["player_id"].toString() || owner!=owner_)return;
            if(status!=200 || result["item_id"]!=part["id"]){status_="Could not confirm the finish. Refresh your inventory.";emit changed();return;}
            if(open_ && appearance_["equipment"].toObject()[field].toObject()["id"]==part["id"]){
                auto colors=appearance_["equipment"].toObject()[field].toObject()["colors"].toObject();
                if(dye=="original")colors.remove(channel);else colors[channel]=dye;
                commit(AvatarAssets::withGarment(appearance_,{{"sku",sku},{"id",part["id"]},{"colors",colors}}));
            }
            refreshGarments();account_.refreshShop();emit changed();
        });
    });
}
QStringList OutfitController::colours() const {
    if(!dyeChannels().isEmpty()){
        QStringList values;
        for(const auto& dye:unlockedDyes())values.append(palette_["colors"].toObject()[dye].toObject()["hex"].toString("#eee8df"));
        return values;
    }
    auto values=AvatarAssets::choices(colourKey());const auto current=appearance_[colourKey()].toString();
    if(!current.isEmpty()&&!values.contains(current))values.append(current);return values;
}
QJsonObject OutfitController::recipe() const {
    QFile manifest(AvatarAssets::packRoot()+"/manifest.json");if(!manifest.open(QIODevice::ReadOnly))return {};
    return {{"schema",1},{"appearance",appearance_},{"packRevision",QString::fromLatin1(QCryptographicHash::hash(manifest.readAll(),QCryptographicHash::Sha256).toHex())}};
}
QVariantMap OutfitController::view() const {
    QVariantList categories;for(int i=0;i<fields.size();++i)categories.append(QVariantMap{{"id",i==5?"outfit":fields[i]},{"name",labels[i]}});
    const auto row=selected(),chosen=items().value(item_).toMap();const auto key=fields[category_];
    const bool full=AvatarAssets::onePiece(appearance_["top"].toString());
    const bool visible=!(category_==2&&full)&&!(category_==1&&full)&&!(category_==5&&!full);
    const bool canRemove=visible&&(category_<5||category_==5)&&appearance_[key]!=AvatarAssets::defaults()[key];
    const bool hasColour=visible&&appearance_[key]!="none";
    const auto channels=dyeChannels();const auto channel=channels.isEmpty()?QString():channels[dyeChannel_%channels.size()];
    const auto finish=appearance_["equipment"].toObject()[key].toObject()["colors"].toObject()[channel].toString("original");
    const auto tint=channels.isEmpty()?appearance_[colourKey()].toString():palette_["colors"].toObject()[finish].toObject()["hex"].toString("#eee8df");
    return {{"rows",rows()},{"selected",row},{"index",index_},{"focus",focus_},{"command",command_},
        {"categories",categories},{"category",category_},{"items",items()},{"item",item_},{"chosen",chosen},
        {"colours",hasColour?colours():QStringList()},{"colour",tint},{"channel",channel},{"dyes",unlockedDyes()},{"painting",painting_},
        {"colourIndex",colour_},{"equippedName",visible?title(appearance_[key].toString()):QString("None")},{"canRemove",canRemove},
        {"appearance",appearance_.toVariantMap()},{"preview",previewUrl_},{"previewBusy",job_.isRunning()},
        {"previewError",previewError_},{"busy",false},{"review",account_.outfits()["review"]},
        {"conflict",row["conflict"].toBool()},{"status",!status_.isEmpty()?status_:account_.outfits()["status"].toString()},
        {"wearing",true},{"replace",false}};
}
QJsonArray OutfitController::shipLooks() const {
    const auto state=account_.wardrobeState();
    const auto live=trainer_.appearance();
    const auto revision=trainer_.avatarDescriptor()["recipe"].toObject()["packRevision"].toString();
    QJsonArray looks;
    bool wearingSlot=false;
    if(revision.isEmpty())return looks;
    for(const auto& entry:account_.outfits()["items"].toList()) {
        const auto row=entry.toMap(), saved=row["saved"].toMap();
        const auto recipe=QJsonObject::fromVariantMap(saved["recipe"].toMap());
        const auto savedAppearance=recipe["appearance"].toObject();
        if(row["conflict"].toBool()||!AvatarAssets::valid(savedAppearance))continue;
        const auto appearance=AvatarAssets::withClothes(savedAppearance,live);
        const bool worn=state["active"].toString()==row["id"].toString() && AvatarAssets::normalized(appearance)==live;
        wearingSlot|=worn;
        // The profile wardrobe already resolves supported old appearances with the installed pack.
        looks.append(QJsonObject{{"id",row["id"].toString()},{"name",saved["name"].toString()},
            {"recipe",QJsonObject{{"schema",1},{"packRevision",revision},{"appearance",appearance}}},{"worn",worn}});
    }
    const auto free=wearingSlot?AvatarAssets::withClothes(state["free"].toObject(),live):live;
    if(AvatarAssets::valid(free))
        looks.prepend(QJsonObject{{"id","current"},{"name",state["freeName"].toString("Everyday")},{"worn",!wearingSlot},
            {"recipe",QJsonObject{{"schema",1},{"packRevision",revision},{"appearance",free}}}});
    return looks;
}
QJsonArray OutfitController::shipParts(const QJsonObject& recipe,const QString& field) const {
    QJsonArray parts;
    if(!QStringList{"headwear","top","bottom","socks","shoes"}.contains(field))return parts;
    const auto appearance=recipe["appearance"].toObject();
    if(recipe.size()!=3||recipe["schema"]!=1||recipe["packRevision"].toString().size()!=64||!AvatarAssets::valid(appearance))return parts;
    for(const auto& item:AvatarAssets::choices(field)){
        auto variant=recipe;
        // Selecting the current garment must preserve its existing dye.
        if(appearance[field]!=item)variant["appearance"]=AvatarAssets::equipped(appearance,field,item);
        parts.append(QJsonObject{{"id",item},{"name",title(item)},{"recipe",variant}});
    }
    for(const auto item:ownedGarments()){
        const auto piece=item.toObject();
        if(AvatarAssets::workshopSlot(piece["sku"].toString())!=field)continue;
        const auto next=AvatarAssets::withGarment(appearance,piece);
        if(next.isEmpty())continue;
        auto variant=recipe;variant["appearance"]=next;
        parts.append(QJsonObject{{"id",piece["id"]},{"name",title(piece["sku"].toString())},{"recipe",variant}});
    }
    return parts;
}
void OutfitController::wearShipLook(const QString& slot,const QJsonObject& expected,const QString& field,const QString& item,std::function<void(QString)> done) {
    if(open_||trainer_.editing()||trainer_.saving()){done("wardrobe_busy");return;}
    const auto looks=shipLooks();
    for(const auto& entry:looks) {
        const auto row=entry.toObject();
        if(row["id"]!=slot || row["recipe"].toObject()!=expected)continue;
        auto recipe=expected;
        if(!field.isEmpty()){
            bool found=false;
            for(const auto& choice:shipParts(expected,field)){
                const auto part=choice.toObject();
                if(part["id"]==item){recipe=part["recipe"].toObject();found=true;break;}
            }
            if(!found){done("invalid_piece");return;}
        }
        if(row["worn"].toBool()&&recipe==expected){done({});return;}
        const auto owner=trainer_.profile()["id"].toString();
        const auto player=account_.snapshot()["player_id"].toString();
        const auto before=trainer_.appearance();
        const auto previousState=account_.wardrobeState();
        auto state=previousState;
        for(const auto& look:looks)
            if(look.toObject()["id"]=="current")state["free"]=look.toObject()["recipe"].toObject()["appearance"];
        state["active"]=slot;
        if(slot=="current")state["free"]=recipe["appearance"];
        const bool changedSlot=slot!="current" && recipe!=expected;
        if(changedSlot) {
            const auto items=account_.outfits()["items"].toList();
            const auto match=std::find_if(items.begin(),items.end(),[&](const QVariant& entry){return entry.toMap()["id"]==slot;});
            if(match==items.end()){done("look_changed");return;}
            const auto saved=match->toMap()["saved"].toMap();
            if(!account_.queueOutfit(slot,saved["name"].toString(),recipe,saved["revision"].toString(),state)){
                done("wardrobe_state_save_failed");return;
            }
        }else if(!account_.storeWardrobeState(state)){done("wardrobe_state_save_failed");return;}
        const auto complete=[this,owner,player,previousState,changedSlot,done](bool saved){
            if(trainer_.profile()["id"].toString()!=owner||account_.snapshot()["player_id"].toString()!=player){done("profile_changed");return;}
            if(saved){done({});return;}
            if(!account_.storeWardrobeState(previousState)){done("wardrobe_state_save_failed");return;}
            done(changedSlot?"look_saved_equip_failed":"appearance_save_failed");
        };
        const auto appearance=AvatarAssets::withClothes(recipe["appearance"].toObject(),before);
        if(AvatarAssets::normalized(appearance)==before)complete(true);
        else if(!trainer_.applyAppearance(appearance,complete))complete(false);
        return;
    }
    done("look_changed");
}
void OutfitController::open(){
    account_.cancelPurchaseReview();open_=true;owner_=trainer_.profile()["id"].toString();player_=account_.snapshot()["player_id"].toString();
    index_=0;focus_=2;status_.clear();liveFailed_=false;nameSlot_.clear();appearance_=trainer_.appearance();
    const auto state=account_.wardrobeState();free_=AvatarAssets::normalized(state["free"].toObject());if(free_.isEmpty())free_=appearance_;
    const auto all=rows();for(int i=1;i<all.size();++i)if(all[i].toMap()["id"]==state["active"].toString()&&!all[i].toMap()["buy"].toBool()) {
        const auto saved=QJsonObject::fromVariantMap(all[i].toMap()["saved"].toMap()["recipe"].toMap())["appearance"].toObject();
        if(!saved.isEmpty()&&AvatarAssets::withClothes(saved,appearance_)==appearance_)index_=i;
    }
    if(index_==0)free_=appearance_;selectCategory(category_);preview();refreshGarments();loadPalette();account_.refreshShop();emit changed();
}
void OutfitController::close(){if(!open_)return;open_=false;++generation_;previewAppearance_={};nameSlot_.clear();account_.cancelPurchaseReview();}
void OutfitController::select(int index){
    if(!open_||!account_.outfits()["review"].toMap().isEmpty())return;
    const auto all=rows();index=qBound(0,index,int(all.size())-1);const auto row=all[index].toMap();
    if(row["buy"].toBool()){account_.reviewOutfitSlot();focus_=0;command_=0;emit changed();return;}
    const auto old=index_;index_=index;
    auto a=index==0?free_:AvatarAssets::normalized(QJsonObject::fromVariantMap(row["saved"].toMap()["recipe"].toMap())["appearance"].toObject());
    a=AvatarAssets::withClothes(a,trainer_.appearance());
    if(a.isEmpty())a=appearance_;if(!commit(a)){index_=old;emit changed();return;}
    selectCategory(category_);focus_=0;emit admired();emit changed();
}
bool OutfitController::commit(const QJsonObject& a){
    if(!AvatarAssets::valid(a))return false;
    const auto old=appearance_;appearance_=AvatarAssets::normalized(a);const auto row=selected();
    const auto free=index_==0?appearance_:free_;
    auto state=account_.wardrobeState();state["active"]=row["id"].toString();state["free"]=free;
    const bool stored=index_==0?account_.storeWardrobeState(state):account_.queueOutfit(row["id"].toString(),row["name"].toString(),recipe(),row["saved"].toMap().value("revision","0").toString(),state);
    if(!stored){appearance_=old;status_="Could not save this set. Please try again.";return false;}
    free_=free;status_.clear();liveFailed_=false;livePending_=true;saveLive();preview();emit changed();return true;
}
void OutfitController::saveLive(){
    if(!livePending_||liveFailed_||trainer_.saving())return;
    if(trainer_.profile()["id"].toString()!=owner_){livePending_=false;return;}
    if(trainer_.appearance()==appearance_){livePending_=false;return;}
    if(!trainer_.applyAppearance(appearance_)){status_="Could not update the current look.";liveFailed_=true;emit changed();}
}
void OutfitController::selectCategory(int category){
    if(!open_)return;category_=qBound(0,category,int(fields.size())-1);item_=0;
    const auto list=items();for(int i=0;i<list.size();++i)if(list[i].toMap()["equipped"].toBool())item_=i;
    colour_=qMax(0,colours().indexOf(appearance_[colourKey()].toString()));focus_=1;emit changed();
}
void OutfitController::selectItem(int index){if(!open_)return;item_=qBound(0,index,int(items().size())-1);focus_=2;emit changed();}
void OutfitController::equip(){
    if(!open_)return;const auto chosen=items().value(item_).toMap();if(chosen.isEmpty())return;
    const auto key=fields[category_];auto a=appearance_;
    if(chosen.contains("garment") && !chosen["equipped"].toBool()){
        if(commit(AvatarAssets::withGarment(a,QJsonObject::fromVariantMap(chosen["garment"].toMap()))))emit admired();
        return;
    }
    const auto value=chosen["equipped"].toBool()&&(category_<5||category_==5)?AvatarAssets::defaults()[key].toString():chosen["id"].toString();
    a=AvatarAssets::equipped(a,key,value);if(a==appearance_)return;
    if(commit(a))emit admired();
}
void OutfitController::chooseColour(int index){
    const auto values=view()["colours"].toStringList();if(!open_||index<0||index>=values.size())return;
    if(!dyeChannels().isEmpty()){colour_=index;focus_=3;paintGarment(unlockedDyes().value(index));emit changed();return;}
    auto a=appearance_;a[colourKey()]=values[index];colour_=index;focus_=3;commit(a);
}
void OutfitController::refresh(){loadPalette();refreshGarments();status_.clear();liveFailed_=false;saveLive();account_.refreshShop();}
void OutfitController::preview(){if(appearance_==previewAppearance_)return;previewAppearance_=appearance_;previewError_.clear();++generation_;if(!job_.isRunning())startPreview();}
void OutfitController::startPreview(){
    jobGeneration_=generation_;if(!open_||!AvatarAssets::valid(previewAppearance_))return;
    const auto appearance=previewAppearance_;const auto cache=cache_.path();job_.setFuture(QtConcurrent::run([appearance,cache]{return AvatarAssets::resolve(appearance,{},cache);}));
}
void OutfitController::activate(int action){
    if(!open_)return;if(action==0){equip();return;}if(action==1){refresh();return;}
    if(action==2){nameSlot_=selected()["id"].toString();emit nameRequested(selected()["name"].toString());}if(action==3)emit admired();
}
void OutfitController::acceptName(const QString& name){
    if(!open_||nameSlot_.isEmpty())return;
    if(nameSlot_=="current") {
        if(!name.trimmed().isEmpty()){auto state=account_.wardrobeState();state["freeName"]=name.trimmed().left(32);if(!account_.storeWardrobeState(state))status_="Could not save the name.";}
        nameSlot_.clear();emit changed();return;
    }
    for(const auto row:rows()){const auto r=row.toMap();if(r["id"]==nameSlot_){const auto saved=r["saved"].toMap();account_.queueOutfit(nameSlot_,name,QJsonObject::fromVariantMap(saved["recipe"].toMap()),saved["revision"].toString());break;}}
    nameSlot_.clear();emit changed();
}
void OutfitController::confirm(bool yes){if(yes)account_.confirmPurchase();else account_.cancelPurchaseReview();emit changed();}
void OutfitController::conflict(bool keepLocal){account_.resolveOutfitConflict(selected()["id"].toString(),keepLocal);if(!keepLocal)select(index_);}
void OutfitController::dispatch(Action action){
    if(!open_)return;
    if(selected()["conflict"].toBool()){
        if(action==Action::Left)command_=0;else if(action==Action::Right)command_=1;
        else if(action==Action::Confirm)conflict(command_==1);
        else if(action==Action::Back){close();emit backRequested();}emit changed();return;
    }
    if(!account_.outfits()["review"].toMap().isEmpty()){
        if(action==Action::Back)confirm(false);else if(action==Action::Left)command_=0;else if(action==Action::Right)command_=1;
        else if(action==Action::Confirm)confirm(command_==1);emit changed();return;
    }
    if(action==Action::Back){close();emit backRequested();return;}
    if(action==Action::PreviousFace||action==Action::NextFace){selectCategory((category_+(action==Action::NextFace?1:fields.size()-1))%fields.size());return;}
    if(action==Action::ScrollUp||action==Action::ScrollDown){emit rotateRequested(action==Action::ScrollUp?-20:20);return;}
    if(action==Action::ContextMenu){if(focus_==3 && !dyeChannels().isEmpty())nextDyeChannel();else activate(2);return;}
    if(action==Action::Confirm){
        if(focus_==0){select(index_);focus_=2;}else if(focus_==1)focus_=2;else if(focus_==2||focus_==4)equip();
        else if(focus_==3)chooseColour(colour_);else if(focus_==5)activate(command_==0?2:command_==1?1:3);emit changed();return;
    }
    const int delta=action==Action::Left||action==Action::Up?-1:1;
    if(action==Action::Up||action==Action::Down){
        if(focus_==0)focus_=2;else if(focus_==1)selectCategory(category_+delta);
        else if(focus_==2){if(item_+delta*3<0)focus_=0;else if(item_+delta*3>=items().size())focus_=3;else item_+=delta*3;}
        else if(focus_==3)focus_=delta<0?2:4;else if(focus_==4)focus_=delta<0?3:5;else if(focus_==5)focus_=delta<0?4:0;
    }else if(action==Action::Left||action==Action::Right){
        if(focus_==0)select(qBound(0,index_+delta,int(rows().size())-1));else if(focus_==1){if(delta<0)focus_=2;}
        else if(focus_==2){if(delta>0&&item_%3==2)focus_=1;else item_=qBound(0,item_+delta,int(items().size())-1);}
        else if(focus_==3)colour_=qBound(0,colour_+delta,qMax(0,int(view()["colours"].toStringList().size())-1));
        else if(focus_==5)command_=qBound(0,command_+delta,2);else if(focus_==4)focus_=1;
    }emit changed();
}
}
