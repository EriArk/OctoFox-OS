#include "../sdk/qt/AvatarScene.h"
#include "features/trainer/AvatarAssets.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QQuick3DGeometry>
#include <QJsonObject>
#include <QThreadPool>
using namespace trainer;
class AvatarSceneTests final:public QObject {
    Q_OBJECT
private slots:
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
