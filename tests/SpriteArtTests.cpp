#include "adapters/pokemon/pokedex/SpriteArt.h"
#include "adapters/pokemon/pokedex/CuboidArt.h"
#include "adapters/pokemon/pokedex/PokedexController.h"
#include "adapters/pokemon/center/PartyPresentation.h"
#include "core/repository/OfflinePokedex.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QCryptographicHash>
#include <QBuffer>
#include <QPainter>
#include <QDir>
#include <QJsonDocument>
#include <QJsonArray>
using namespace trainer;
class SpriteArtTests final : public QObject {
    Q_OBJECT
    QString fixture(const QString& dir, const QSize& size = QSize(40,40), const QString& path = {}) {
        QImage image(size,QImage::Format_ARGB32); image.fill(Qt::green);
        QByteArray bytes; QBuffer buffer(&bytes); buffer.open(QIODevice::WriteOnly); image.save(&buffer,"PNG");
        const auto id = QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex());
        QDir(dir).mkpath("images"); QFile file(dir+"/images/"+id+".png");
        if (!file.open(QIODevice::WriteOnly)) return {};
        file.write(bytes); file.close();
        QJsonObject asset{{"file",path.isEmpty()?"images/"+id+".png":path},{"credit","Original test fixture"},
            {"source","TrainerOS test"},{"license","Test-only original geometry"}};
        QJsonObject root{{"version",1},{"kind","pmd-detail-preview"},
            {"targets",QJsonObject{{"vulpix/37",QJsonArray{QJsonObject{{"asset",id},{"label","Portrait"}}}}}},
            {"assets",QJsonObject{{id,asset}}}};
        QFile manifest(dir+"/sprite-index.json"); if (!manifest.open(QIODevice::WriteOnly)) return {};
        manifest.write(QJsonDocument(root).toJson()); return id;
    }
private slots:
    void installedLegacySpritesAreInactiveByDefault() {
        QTemporaryDir dir;const auto id=fixture(dir.path());QVERIFY(!id.isEmpty());
        QFile index(dir.filePath("sprite-index.json")),image(dir.filePath("images/"+id+".png"));
        QVERIFY(index.open(QIODevice::ReadOnly));QVERIFY(image.open(QIODevice::ReadOnly));
        const auto indexBefore=index.readAll(),imageBefore=image.readAll();
        SpriteArt sprites(dir.path());ClassicArt art(dir.path());
        const auto choices=sprites.choices("vulpix/37");QCOMPARE(choices.size(),9);
        for(const auto& value:choices) {
            const auto row=value.toMap();QVERIFY(row["builtin"].toBool());
            QVERIFY(!sprites.requestImage(row["id"].toString(),nullptr,{}).isNull());
        }
        QVERIFY(sprites.requestImage(id,nullptr,{}).isNull());
        PartyPresentation party(false);party.configureArtwork(&art,&sprites);party.setAdventure("game","Game");
        GameProgress progress;progress.availability=ProgressAvailability::Available;
        PartySnapshot snapshot;PokemonRecord mon;mon.kind=PokemonSlotKind::Known;mon.speciesId="vulpix";mon.formId="37";
        snapshot.party.append(mon);progress.party=snapshot;progress.saveRevision="one";party.setProgress("game",progress);
        const auto actor=party.activities()->actors().first().toMap();
        for(const auto& kind:{"clips","portraits"}) {
            const auto rows=actor[kind].toMap();QVERIFY(!rows.isEmpty());
            for(const auto& value:rows)QVERIFY(value.toMap()["builtin"].toBool());
        }
        QVERIFY(index.seek(0));QVERIFY(image.seek(0));
        QCOMPARE(index.readAll(),indexBefore);QCOMPARE(image.readAll(),imageBefore);
    }

    void renderBuiltinReviewSheet() {
        const QStringList targets{"pikachu/25","bulbasaur/1","charmander/4","zubat/41","unknown/1","squirtle/7","onix/95","mudkip/258","eevee/133","snorlax/143"};
        QImage sheet(960,480,QImage::Format_ARGB32);sheet.fill(QColor("#f5f1e5"));QPainter p(&sheet);
        QDir().mkpath("screenshots/cuboids");
        for(int i=0;i<targets.size();++i) {
            const auto image=CuboidArt::render("cuboid/v1/"+targets[i]+"/Normal");
            p.drawImage(QPoint((i%5)*192+16,(i/5)*240),image);
            p.drawImage(QRect((i%5)*192+64,(i/5)*240+170,48,48),image);
            for(const auto& action:{QString("Idle"),QString("WalkLeft"),QString("WalkRight"),QString("WalkUp"),QString("WalkDown"),QString("Sleep")})
                QVERIFY(CuboidArt::render("cuboid/v1/"+targets[i]+"/"+action).save("screenshots/cuboids/"+targets[i].section('/',0,0)+"-"+action+".png"));
        }
        p.end();QVERIFY(sheet.save("screenshots/cuboids/review.png"));
    }
    void builtinsCoverCatalogueAndUnknownWithoutChangingIdentity() {
        OfflinePokedex reference; const auto catalog=reference.load(); QVERIFY(catalog.success);
        // Loading a known built-in also initializes its compiled resource.
        QVERIFY(!CuboidArt::render("cuboid/v1/pikachu/25/Normal").isNull());
        QFile mapping(":/cuboids/cuboid-creatures.json");QVERIFY(mapping.open(QIODevice::ReadOnly));
        const auto targets=QJsonDocument::fromJson(mapping.readAll()).object()["targets"].toObject();
        QImage gallery(24*48,17*48,QImage::Format_ARGB32);gallery.fill(QColor("#f5f1e5"));QPainter galleryPainter(&gallery);
        int forms=0;
        for(const auto& entry:catalog.entries)for(const auto& form:entry.forms) {
            const auto target=entry.id+'/'+form.id; const auto rows=CuboidArt::choices(target);
            QCOMPARE(rows.size(),9); ++forms;
            QVERIFY2(targets.contains(target),qPrintable(target));
            const auto portrait=CuboidArt::render("cuboid/v1/"+target+"/Normal");QVERIFY(!portrait.isNull());
            for(int edge=0;edge<160;++edge) {
                QVERIFY2(qAlpha(portrait.pixel(0,edge))==0&&qAlpha(portrait.pixel(159,edge))==0
                    &&qAlpha(portrait.pixel(edge,0))==0&&qAlpha(portrait.pixel(edge,159))==0,qPrintable(target));
            }
            if(entry.number<=386 && form.id==QString::number(entry.number)) {
                const int n=entry.number-1;galleryPainter.drawImage(QRect((n%24)*48,(n/24)*48,48,48),portrait);
            }
            for(const auto& item:rows) {const auto row=item.toMap();
                QVERIFY(row["builtin"].toBool()); QVERIFY(row["id"].toString().contains('/'+target+'/'));
            }
        }
        QCOMPARE(forms,1579);
        QCOMPARE(targets.size(),forms);galleryPainter.end();QDir().mkpath("screenshots/cuboids");
        QVERIFY(gallery.save("screenshots/cuboids/emerald-386.png"));
        QVERIFY(CuboidArt::choices("../bad/1").isEmpty());
        QVERIFY(CuboidArt::render("cuboid/v1/pikachu/25/UnknownAction").isNull());
        QCOMPARE(CuboidArt::render("cuboid/v1/unknown/1/Normal"),CuboidArt::render("cuboid/v1/unknown/2/Normal"));
    }
    void builtinFramesHaveFixedCanvasAlphaAndDistinctActions() {
        SpriteArt sprites("");
        for(const auto& target:{QString("pikachu/25"),QString("bulbasaur/1"),QString("charmander/4"),QString("zubat/41"),QString("unknown/1")}) {
            QImage idle;
            for(const auto& value:sprites.choices(target)) {
                const auto row=value.toMap();const auto id=row["id"].toString();
                const auto image=sprites.requestImage(id,nullptr,{});QVERIFY(!image.isNull());
                QCOMPARE(image.size(),row["kind"]=="sprite"?QSize(384,96):QSize(160,160));
                QVERIFY(image.hasAlphaChannel());QCOMPARE(qAlpha(image.pixel(0,0)),0);
                QCOMPARE(sprites.requestImage(id+"/trimmed",nullptr,{}),image);
                QCOMPARE(sprites.requestImage(id,nullptr,{}),image);
                if(row["action"]=="Idle") {idle=image;QVERIFY(image.copy(0,0,96,96)!=image.copy(192,0,96,96));}
                if(row["action"]=="Sleep")QVERIFY(image!=idle);
            }
            QCOMPARE(sprites.requestImage("cuboid/v1/"+target+"/pokedexDetailArt",nullptr,{}).size(),QSize(480,400));
        }
    }
    void removalRestoresBuiltinWithoutPackWrites() {
        QTemporaryDir dir;fixture(dir.path());
        {SpriteArt installed(dir.path(), ArtSource::Imported);QVERIFY(!installed.choices("vulpix/37").first().toMap()["builtin"].toBool());}
        QVERIFY(QFile::remove(dir.filePath("sprite-index.json")));
        SpriteArt removed(dir.path(), ArtSource::Imported);QCOMPARE(removed.choices("vulpix/37").size(),9);
        QVERIFY(removed.choices("vulpix/37").first().toMap()["builtin"].toBool());
        QVERIFY(!QFile::exists(dir.filePath("sprite-index.json")));
    }
    void partialUserClipsOverrideOnlyTheirOwnAction() {
        QTemporaryDir dir;const auto id=fixture(dir.path());
        QFile f(dir.filePath("sprite-index.json"));QVERIFY(f.open(QIODevice::ReadOnly));
        auto root=QJsonDocument::fromJson(f.readAll()).object();f.close();
        auto assets=root["assets"].toObject();auto asset=assets[id].toObject();asset["kind"]="sprite";asset["action"]="Idle";
        assets[id]=asset;root["assets"]=assets;QVERIFY(f.open(QIODevice::WriteOnly));f.write(QJsonDocument(root).toJson());f.close();
        SpriteArt sprites(dir.path(), ArtSource::Imported);const auto choices=sprites.choices("vulpix/37");QCOMPARE(choices.size(),9);
        QCOMPARE(choices.first().toMap()["url"].toString(),"image://sprite-detail/"+id);
        int idle=0;for(const auto& value:choices){const auto row=value.toMap();
            if(row["action"]=="Idle"){++idle;QVERIFY(!row["builtin"].toBool());}
            else QVERIFY(row["builtin"].toBool());}
        QCOMPARE(idle,1);
        ClassicArt art("");QVERIFY(art.image("vulpix/37","pokedexDetailArt")["builtin"].toBool());
    }
    void partyKeepsPortraitsSeparateFromAnimationAndExactForm() {
        QTemporaryDir dir;const auto id=fixture(dir.path());
        QFile file(dir.filePath("sprite-index.json"));QVERIFY(file.open(QIODevice::ReadOnly));
        auto root=QJsonDocument::fromJson(file.readAll()).object();file.close();
        auto assets=root["assets"].toObject();auto face=assets[id].toObject();
        face["kind"]="portrait";face["action"]="Normal";assets[id]=face;root["assets"]=assets;
        QVERIFY(file.open(QIODevice::WriteOnly));file.write(QJsonDocument(root).toJson());file.close();
        SpriteArt sprites(dir.path(), ArtSource::Imported);PartyPresentation party(false);party.configureArtwork(nullptr,&sprites);
        party.setAdventure("game","Game");GameProgress progress;progress.availability=ProgressAvailability::Available;
        PartySnapshot snapshot;PokemonRecord mon;mon.kind=PokemonSlotKind::Known;mon.speciesId="vulpix";mon.formId="37";
        snapshot.party.append(mon);progress.party=snapshot;progress.saveRevision="one";party.setProgress("game",progress);
        auto row=party.activities()->actors().first().toMap();
        QCOMPARE(row["portraits"].toMap()["Normal"].toMap()["url"].toString(),"image://sprite-detail/"+id);
        QCOMPARE(row["clips"].toMap().size(),6);
        QVERIFY(row["clips"].toMap()["Idle"].toMap()["builtin"].toBool());
        progress.party->party[0].formId="10205";progress.saveRevision="two";party.setProgress("game",progress);
        QVERIFY(party.activities()->actors().first().toMap()["portraits"].toMap()["Normal"].toMap()["builtin"].toBool());
    }
    void fittedCompanionCropsPaddingAcrossAllFrames() {
        QTemporaryDir dir;QDir(dir.path()).mkpath("images");
        QImage sheet(40,20,QImage::Format_ARGB32);sheet.fill(Qt::transparent);
        sheet.setPixelColor(3,4,Qt::red);sheet.setPixelColor(27,12,Qt::blue);
        QByteArray bytes;QBuffer buffer(&bytes);buffer.open(QIODevice::WriteOnly);QVERIFY(sheet.save(&buffer,"PNG"));
        const auto id=QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex());
        QFile image(dir.filePath("images/"+id+".png"));QVERIFY(image.open(QIODevice::WriteOnly));image.write(bytes);image.close();
        QJsonObject asset{{"file","images/"+id+".png"},{"frames",2},{"frameWidth",20},{"durations",QJsonArray{100,100}},
            {"credit","Original fixture"},{"source","Test"},{"license","Test"}};
        QFile manifest(dir.filePath("sprite-index.json"));QVERIFY(manifest.open(QIODevice::WriteOnly));
        manifest.write(QJsonDocument(QJsonObject{{"version",1},{"kind","pmd-detail-preview"},{"targets",QJsonObject{}},{"assets",QJsonObject{{id,asset}}}}).toJson());manifest.close();
        SpriteArt sprites(dir.path(), ArtSource::Imported);const auto fitted=sprites.requestImage(id+"/trimmed",nullptr,{});
        QCOMPARE(fitted.size(),QSize(10,9));QCOMPARE(fitted.pixelColor(0,0),QColor(Qt::red));QCOMPARE(fitted.pixelColor(9,8),QColor(Qt::blue));
        QCOMPARE(sprites.requestImage(id,nullptr,{}),sheet); // Original/private source is unchanged.
        QCOMPARE(sprites.requestImage(id+"/trimmed",nullptr,{}),fitted);
    }
    void exactIdentityAndBoundedDecode() {
        QTemporaryDir dir; auto id=fixture(dir.path()); QVERIFY(!id.isEmpty()); SpriteArt sprites(dir.path(), ArtSource::Imported);
        QCOMPARE(sprites.choices("vulpix/37").size(),10);
        QVERIFY(sprites.choices("vulpix/10205").first().toMap()["builtin"].toBool()); // Never substitute the ordinary user form.
        QVERIFY(sprites.choices("vulpix/37/shiny").isEmpty());
        QSize size; auto image=sprites.requestImage(id,&size,QSize(9999,9999));
        QCOMPARE(size,QSize(40,40)); QCOMPARE(image.size(),QSize(40,40));
        QVERIFY(sprites.requestImage("unknown",&size,{}).isNull());
        QCOMPARE(SpriteArt("").choices("vulpix/37").size(),9);
    }
    void badHashPathsAndPixelBomb() {
        QTemporaryDir dir; const auto id=fixture(dir.path());
        QFile damaged(dir.path()+"/images/"+id+".png"); QVERIFY(damaged.open(QIODevice::WriteOnly)); damaged.write("bad"); damaged.close();
        SpriteArt corrupt(dir.path(), ArtSource::Imported); QVERIFY(corrupt.requestImage(id,nullptr,{}).isNull());
        fixture(dir.path(),QSize(40,40),"../outside.png"); SpriteArt escaped(dir.path(), ArtSource::Imported); QCOMPARE(escaped.choices("vulpix/37").size(),9);
        const auto large=fixture(dir.path(),QSize(257,40)); SpriteArt oversized(dir.path(), ArtSource::Imported); QVERIFY(oversized.requestImage(large,nullptr,{}).isNull());
        QVERIFY(oversized.requestImage("../"+large,nullptr,{}).isNull());
    }
    void controllerRestoresIllustrationDetailAndForm() {
        QTemporaryDir dir; fixture(dir.path()); SpriteArt sprites(dir.path(), ArtSource::Imported);
        OfflinePokedex reference; MockPokedexRepository progress; PokedexController dex(reference,progress);
        dex.configureSprites(&sprites); dex.applySearch("37"); dex.activateControl("list",0);
        const auto original=dex.detail(); dex.dispatch(Action::Down); QCOMPARE(dex.zone(),"list");
        QCOMPARE(dex.spriteChoices().size(),10); QCOMPARE(dex.detail(),original);
        dex.activateControl("rail",7); QCOMPARE(dex.zone(),"art"); dex.dispatch(Action::Back);
        dex.cycleForm(); QCOMPARE(dex.spriteChoices().size(),9);
        dex.cancelTransient(); QCOMPARE(dex.zone(),"list");
        dex.dispatch(Action::Back); QCOMPARE(dex.zone(),"list");
        dex.dispatch(Action::LocalAction); QCOMPARE(dex.zone(),"rail");
    }
};
QTEST_GUILESS_MAIN(SpriteArtTests)
#include "SpriteArtTests.moc"
