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
using namespace trainer;
class AvatarSceneTests final:public QObject {
    Q_OBJECT
private slots:
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
