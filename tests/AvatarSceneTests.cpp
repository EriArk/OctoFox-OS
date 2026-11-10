#include "../sdk/qt/AvatarScene.h"
#include "features/trainer/AvatarAssets.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QQuick3DGeometry>
#include <QJsonObject>
#include <QThreadPool>
#include <QMatrix4x4>
#include <QQuaternion>
#include <cstring>
#include <functional>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QJsonArray>
#include <QJsonDocument>
#include <QtEndian>
using namespace trainer;
class AvatarSceneTests final:public QObject {
    Q_OBJECT
private slots:
    void sharedAccessorsKeepDrawnAttributesAndOnlyUploadAffectedMorphs(){
        QTemporaryDir folder;QByteArray binary;QJsonArray views,accessors;
        auto floats=[&](const QVector<float>& values,const QString& type,int width){
            const int start=binary.size();
            for(float value:values){quint32 bits;std::memcpy(&bits,&value,4);bits=qToLittleEndian(bits);binary.append(reinterpret_cast<const char*>(&bits),4);}
            const int view=views.size();views.append(QJsonObject{{"buffer",0},{"byteOffset",start},{"byteLength",binary.size()-start}});
            const int id=accessors.size();accessors.append(QJsonObject{{"bufferView",view},{"componentType",5126},{"count",values.size()/width},{"type",type}});return id;
        };
        auto indices=[&](QVector<quint32> values){
            const int start=binary.size();for(auto value:values){value=qToLittleEndian(value);binary.append(reinterpret_cast<const char*>(&value),4);}
            const int view=views.size();views.append(QJsonObject{{"buffer",0},{"byteOffset",start},{"byteLength",binary.size()-start}});
            const int id=accessors.size();accessors.append(QJsonObject{{"bufferView",view},{"componentType",5125},{"count",values.size()},{"type","SCALAR"}});return id;
        };
        auto jointAccessor=[&]{
            const int start=binary.size();binary.append(QByteArray(6*4*2,'\0'));
            const int view=views.size();views.append(QJsonObject{{"buffer",0},{"byteOffset",start},{"byteLength",48}});
            const int id=accessors.size();accessors.append(QJsonObject{{"bufferView",view},{"componentType",5123},{"count",6},{"type","VEC4"}});return id;
        };
        QVector<float> positions,normals,uv,colors,weights,morph;
        for(int i=0;i<6;++i){positions<<float(i)<<float(i+1)<<float(i+2);normals<<0<<0<<1;uv<<float(i)/8<<float(i)/16;colors<<float(i)/8<<.5f<<.25f<<1;weights<<1<<0<<0<<0;morph<<(i==2?.25f:0.f)<<0<<0;}
        const QJsonObject attributes{{"POSITION",floats(positions,"VEC3",3)},{"NORMAL",floats(normals,"VEC3",3)},
            {"TEXCOORD_0",floats(uv,"VEC2",2)},{"COLOR_0",floats(colors,"VEC4",4)},
            {"JOINTS_0",jointAccessor()},{"WEIGHTS_0",floats(weights,"VEC4",4)}};
        const QJsonArray targets{QJsonObject{{"POSITION",floats(morph,"VEC3",3)}}};
        const QJsonArray primitives{QJsonObject{{"attributes",attributes},{"indices",indices({4,0,2})},{"targets",targets}},
            QJsonObject{{"attributes",attributes},{"indices",indices({5,1,3})},{"targets",targets}}};
        const QJsonObject document{{"asset",QJsonObject{{"version","2.0"}}},{"scene",0},
            {"scenes",QJsonArray{QJsonObject{{"nodes",QJsonArray{0,1}}}}},
            {"nodes",QJsonArray{QJsonObject{{"mesh",0},{"skin",0}},QJsonObject{{"name","head"},{"translation",QJsonArray{2,3,4}}}}},
            {"skins",QJsonArray{QJsonObject{{"joints",QJsonArray{1}}}}},
            {"meshes",QJsonArray{QJsonObject{{"primitives",primitives},{"extras",QJsonObject{{"targetNames",QJsonArray{"blink"}}}}}}},
            {"extras",QJsonObject{{"trainerFace",QJsonObject{{"controls",QJsonArray{"blink"}}}}}},
            {"buffers",QJsonArray{QJsonObject{{"byteLength",binary.size()}}}},{"bufferViews",views},{"accessors",accessors}};
        auto json=QJsonDocument(document).toJson(QJsonDocument::Compact);while(json.size()%4)json.append(' ');
        QByteArray glb;auto word=[&](quint32 value){value=qToLittleEndian(value);glb.append(reinterpret_cast<const char*>(&value),4);};
        word(0x46546c67);word(2);word(28+json.size()+binary.size());word(json.size());word(0x4e4f534a);glb+=json;word(binary.size());word(0x004e4942);glb+=binary;
        QFile file(folder.filePath("shared.glb"));QVERIFY(file.open(QIODevice::WriteOnly));QCOMPARE(file.write(glb),glb.size());file.close();
        AvatarScene cpu,gpu;gpu.setGpuSkinning(true);const auto source=QUrl::fromLocalFile(file.fileName());cpu.setSource(source);gpu.setSource(source);
        QTRY_VERIFY_WITH_TIMEOUT(cpu.ready()&&gpu.ready(),10000);QCOMPARE(gpu.vertexCount(),6);QCOMPARE(cpu.vertexCount(),6);
        auto verify=[&](AvatarScene& scene,bool skinned,float face){
            QCOMPARE(scene.parts().size(),2);
            for(int part=0;part<2;++part){auto* geometry=scene.parts()[part].toMap()["geometry"].value<QQuick3DGeometry*>();
                const auto vertices=geometry->vertexData(),draw=geometry->indexData();QCOMPARE(vertices.size()/geometry->stride(),3);QCOMPARE(draw.size(),12);
                quint32 actual[3];std::memcpy(actual,draw.constData(),12);QCOMPARE(actual[0],2u);QCOMPARE(actual[1],0u);QCOMPARE(actual[2],1u);
                for(int i=0;i<3;++i){const int original=i*2+part;float attributes[12];std::memcpy(attributes,vertices.constData()+i*geometry->stride(),48);
                    QCOMPARE(attributes[0],float(original)+(skinned?2:0)+(original==2?.25f*face:0));
                    QCOMPARE(attributes[1],float(original+1)+(skinned?3:0));QCOMPARE(attributes[2],float(original+2)+(skinned?4:0));
                    QCOMPARE(attributes[3],0.f);QCOMPARE(attributes[4],0.f);QCOMPARE(attributes[5],1.f);
                    QCOMPARE(attributes[6],float(original)/8);QCOMPARE(attributes[7],float(original)/16);
                    QCOMPARE(attributes[8],float(original)/8);QCOMPARE(attributes[9],.5f);QCOMPARE(attributes[10],.25f);QCOMPARE(attributes[11],1.f);
                    qint32 bones[4];float skinWeights[4];std::memcpy(bones,vertices.constData()+i*geometry->stride()+48,16);std::memcpy(skinWeights,vertices.constData()+i*geometry->stride()+64,16);
                    QCOMPARE(bones[0],0);QCOMPARE(skinWeights[0],1.f);
                }
            }
        };
        verify(cpu,true,0);verify(gpu,false,0);const int uploads=gpu.geometryUploads();
        cpu.setFace({{"blink",1.}});gpu.setFace({{"blink",1.}});verify(cpu,true,1);verify(gpu,false,1);
        QCOMPARE(gpu.geometryUploads(),uploads+1); // The other material has no affected vertex.
        QVERIFY(gpu.nodePoseUpdates().isEmpty()); // A blink does not change any joint.
        const auto rest=gpu.nodePoses();
        gpu.setPose({{"head",QVariant::fromValue(QVector3D(0,20,0))}});
        QCOMPARE(gpu.nodePoseUpdates().size(),1);
        const auto changed=gpu.nodePoseUpdates()[0].toMap();QCOMPARE(changed["index"].toInt(),1);
        QCOMPARE(changed["rotation"].value<QQuaternion>(),QQuaternion::fromEulerAngles(0,20,0));
        QCOMPARE(gpu.nodePoses()[0],rest[0]);QVERIFY(gpu.nodePoses()[1]!=rest[1]);
        gpu.setPose({});QCOMPARE(gpu.nodePoseUpdates().size(),1);QCOMPARE(gpu.nodePoses(),rest);
        gpu.setSource({});QVERIFY(gpu.nodePoses().isEmpty());QVERIFY(gpu.nodePoseUpdates().isEmpty());
    }
    void idleDirectorVarietyEligibilityAndPause(){
        QQmlEngine engine;QQmlComponent component(&engine,QUrl::fromLocalFile(TRAINER_AVATAR_IDLE_QML));
        QScopedPointer<QObject> idle(component.create());QVERIFY2(idle,qPrintable(component.errorString()));
        idle->setProperty("automatic",false);idle->setProperty("seed",1234);idle->setProperty("enabled",true);
        QString last;QSet<QString> seen;int changes=0;
        for(int i=0;i<6000;++i){
            QVERIFY(QMetaObject::invokeMethod(idle.data(),"advance",Q_ARG(QVariant,.1)));
            const auto state=idle->property("behavior").toString();
            if(state!="pause" && state!=last){seen.insert(state);last=state;++changes;}
        }
        QCOMPARE(seen.size(),7);QVERIFY(changes>30);
        idle->setProperty("enabled",false);QCOMPARE(idle->property("action").toString(),QString());
        const auto clock=idle->property("clock");QMetaObject::invokeMethod(idle.data(),"advance",Q_ARG(QVariant,10.));
        QCOMPARE(idle->property("clock"),clock);QVERIFY(!idle->property("seated").toBool());
        idle->setProperty("energy",30);idle->setProperty("enabled",true);
        for(int i=0;i<3000;++i){QMetaObject::invokeMethod(idle.data(),"advance",Q_ARG(QVariant,.1));QVERIFY(idle->property("behavior").toString()!="stretch");}
    }
    void runningClipChangesBlendAndCanBeInterrupted(){
        QTemporaryDir cache;const auto avatar=AvatarAssets::resolve(AvatarAssets::defaults(),{},cache.path());
        AvatarScene scene;scene.setGpuSkinning(true);scene.setSource(QUrl::fromLocalFile(avatar["glb"].toString()));
        QTRY_VERIFY_WITH_TIMEOUT(scene.ready(),10000);const auto standing=scene.nodePoses();
        scene.setRunning(true);scene.setClipPosition(.5);scene.setClip("Sit");QTest::qWait(110);
        const auto between=scene.nodePoses();QVERIFY(between!=standing);
        QTest::qWait(400);const auto sitting=scene.nodePoses();QVERIFY(between!=sitting);
        scene.setClip("Arms_Up");QTest::qWait(90);scene.setClip("");QTest::qWait(450);
        QCOMPARE(scene.nodePoses(),standing);scene.setRunning(false);
    }
    void gpuSkinMatchesCpuWithoutPoseUploads(){
        QTemporaryDir cache;auto appearance=AvatarAssets::defaults();
        appearance["top"]="rose-racing-suit";appearance["shoes"]="rose-racing-boots";
        const auto avatar=AvatarAssets::resolve(appearance,{},cache.path());
        QVERIFY2(!avatar.contains("error"),qPrintable(avatar["error"].toString()));
        AvatarScene cpu,gpu;gpu.setGpuSkinning(true);
        const auto source=QUrl::fromLocalFile(avatar["glb"].toString());cpu.setSource(source);gpu.setSource(source);
        QTRY_VERIFY_WITH_TIMEOUT(cpu.ready()&&gpu.ready(),10000);
        QCOMPARE(cpu.vertexCount(),gpu.vertexCount());
        auto verify=[&]{
            const auto poses=gpu.nodePoses();QVector<QMatrix4x4> world(poses.size());QVector<bool> seen(poses.size());
            std::function<QMatrix4x4(int)> matrix=[&](int i){if(seen[i])return world[i];const auto p=poses[i].toMap();QMatrix4x4 m;
                m.translate(p["position"].value<QVector3D>());m.rotate(p["rotation"].value<QQuaternion>());m.scale(p["scale"].value<QVector3D>());
                if(p["parent"].toInt()>=0)m=matrix(p["parent"].toInt())*m;seen[i]=true;return world[i]=m;};
            for(int i=0;i<poses.size();++i)matrix(i);
            for(int part=0;part<gpu.parts().size();++part){
                const auto row=gpu.parts()[part].toMap();auto* g=row["geometry"].value<QQuick3DGeometry*>();
                auto* c=cpu.parts()[part].toMap()["geometry"].value<QQuick3DGeometry*>();
                const auto gb=g->vertexData(),cb=c->vertexData();const int count=gb.size()/g->stride();
                if(row["skin"].toInt()<0)continue;
                const auto rig=gpu.rigs()[row["skin"].toInt()].toMap();const auto joints=rig["joints"].toList(),inverse=rig["inverse"].toList();
                for(int i=0;i<count;i+=std::max(1,count/100)){
                    float input[3],expected[3],weights[4];qint32 indices[4];
                    std::memcpy(input,gb.constData()+i*g->stride(),12);std::memcpy(expected,cb.constData()+i*c->stride(),12);
                    std::memcpy(indices,gb.constData()+i*g->stride()+48,16);std::memcpy(weights,gb.constData()+i*g->stride()+64,16);
                    QVector3D actual;for(int j=0;j<4;++j)actual+=(world[joints[indices[j]].toInt()]*inverse[indices[j]].value<QMatrix4x4>()).map(QVector3D(input[0],input[1],input[2]))*weights[j];
                    QVERIFY((actual-QVector3D(expected[0],expected[1],expected[2])).length()<.0001f);
                }
            }
        };
        verify();cpu.setExpression("laughing");gpu.setExpression("laughing");verify();
        cpu.setClipPosition(.5);gpu.setClipPosition(.5);cpu.setClip("Sit");gpu.setClip("Sit");verify();
        const int uploads=gpu.geometryUploads();const QVariantMap pose{{"head",QVariant::fromValue(QVector3D(7,12,0))}};
        cpu.setPose(pose);gpu.setPose(pose);verify();QCOMPARE(gpu.geometryUploads(),uploads);
        cpu.setClip("Arms_Up");gpu.setClip("Arms_Up");verify();
        auto cost=[&](AvatarScene& scene){QElapsedTimer t;t.start();for(int i=0;i<24;++i)scene.setPose({{"head",QVariant::fromValue(QVector3D(0,i,0))}});return t.nsecsElapsed()/1000000.;};
        qInfo()<<"24 dressed pose frames CPU reference ms"<<cost(cpu)<<"GPU palette ms"<<cost(gpu);
        QPointer<QQuick3DGeometry> geometry=gpu.parts()[0].toMap()["geometry"].value<QQuick3DGeometry*>();
        gpu.setSource({});QTRY_VERIFY(geometry.isNull());QVERIFY(gpu.nodePoses().isEmpty());QVERIFY(gpu.rigs().isEmpty());
    }
    void resolvedModelFacesAndSkin(){
        QTemporaryDir cache;
        const auto avatar=AvatarAssets::resolve(AvatarAssets::defaults(),{},cache.path());
        QVERIFY2(!avatar.contains("error"),qPrintable(avatar["error"].toString()));
        AvatarScene scene;QElapsedTimer load;load.start();scene.setSource(QUrl::fromLocalFile(avatar["glb"].toString()));
        QVERIFY(load.elapsed()<100); // Parsing must leave the GUI event loop responsive.
        QTRY_VERIFY_WITH_TIMEOUT(scene.ready()||!scene.error().isEmpty(),10000);
        qInfo()<<"Background avatar load milliseconds"<<load.elapsed()<<"vertices"<<scene.vertexCount();
        QVERIFY2(scene.ready(),qPrintable(scene.error()));QVERIFY(scene.vertexCount()>1000);
        QVERIFY(scene.supportsExpression("happy"));QVERIFY(scene.supportsExpression("tired"));QVERIFY(scene.supportsClip("Sit"));
        QSignalSpy models(&scene,&AvatarScene::modelChanged);
        auto vertices=[&]{QByteArray bytes;for(const auto& part:scene.parts())bytes+=part.toMap()["geometry"].value<QQuick3DGeometry*>()->vertexData();return bytes;};
        const auto neutral=vertices();
        scene.setExpression("laughing");scene.setRunning(true);QTest::qWait(450);scene.setRunning(false);QVERIFY(vertices()!=neutral);
        const auto face=vertices();scene.setClip("Sit");scene.setClipPosition(.5);QVERIFY(vertices()!=face);
        QSignalSpy frames(&scene,&AvatarScene::frameChanged);QTest::qWait(130);QCOMPARE(frames.size(),0);
        scene.setRunning(true);QTest::qWait(1100);frames.clear();QTest::qWait(150);QCOMPARE(frames.size(),0);scene.setRunning(false);
        scene.setExpression("not-an-expression");QCOMPARE(scene.expression(),"laughing");
        scene.setFace({{"unknown",1.}});QVERIFY(scene.face().isEmpty());
        QCOMPARE(models.size(),0); // Poses must not rebuild QML mesh/material delegates.
        QVERIFY(scene.sockets().contains("hand.R"));
        scene.setSource({});QVERIFY(!scene.ready());QCOMPARE(scene.vertexCount(),0);QVERIFY(scene.sockets().isEmpty());
    }
    void rejectInvalidSource(){AvatarScene scene;scene.setSource(QUrl("https://example.com/avatar.glb"));QVERIFY(!scene.ready());QTRY_VERIFY(!scene.error().isEmpty());}
    void revokeWhileLoading(){
        QTemporaryDir cache;const auto avatar=AvatarAssets::resolve(AvatarAssets::defaults(),{},cache.path());
        AvatarScene scene;scene.setSource(QUrl::fromLocalFile(avatar["glb"].toString()));scene.setSource({});
        QVERIFY(QThreadPool::globalInstance()->waitForDone(10000));QCoreApplication::processEvents();
        QVERIFY(!scene.ready());QVERIFY(scene.parts().isEmpty());QVERIFY(scene.sockets().isEmpty());QVERIFY(scene.error().isEmpty());
    }
};
QTEST_MAIN(AvatarSceneTests)
#include "AvatarSceneTests.moc"
