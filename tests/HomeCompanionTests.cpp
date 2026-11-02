#include "features/home/HomeCompanion.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QSettings>
#include <QDateTime>
using namespace trainer;
class HomeCompanionTests final:public QObject {
    Q_OBJECT
    QTemporaryDir storage;
private slots:
    void initTestCase(){QCoreApplication::setOrganizationName("TrainerOS-test");QCoreApplication::setApplicationName("home-companion");QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,storage.path());}
    void init(){QSettings().clear();}
    void slowOfflineAndClockRollback(){
        HomeCompanion p;p.setOwner("a");const auto first=p.needs();const auto now=QDateTime::currentMSecsSinceEpoch();
        p.advanceTo(now+3600000);QCOMPARE(p.needs()["food"].toInt(),first["food"].toInt()-2);
        p.advanceTo(now+86400000LL*365);QVERIFY(p.needs()["food"].toInt()>=60);
        const auto after=p.needs();p.advanceTo(now);QCOMPARE(p.needs(),after);
        p.advanceTo(now+3600000);QCOMPARE(p.needs()["food"].toInt(),after["food"].toInt()-2);
    }
    void actionsPersistenceAndOwnerIsolation(){
        {HomeCompanion p;p.setOwner("a");p.setActive(true);p.perform(0);QCOMPARE(p.needs()["food"].toInt(),100);p.perform(1);QCOMPARE(p.activity(),QString("feed"));p.perform(3);p.perform(4);p.setActive(false);}
        HomeCompanion p;p.setOwner("a");QCOMPARE(p.needs()["food"].toInt(),100);QCOMPARE(p.background(),QString("sunny-garden"));QVERIFY(p.quiet());
        p.setOwner("b");QCOMPARE(p.needs()["food"].toInt(),80);QVERIFY(!p.quiet());QCOMPARE(p.background(),QString("cozy-room"));
        p.setOwner("a");QCOMPARE(p.background(),QString("sunny-garden"));
    }
    void restAndInactiveInput(){
        HomeCompanion p;p.setOwner("a");p.perform(0);QCOMPARE(p.needs()["food"].toInt(),80);
        p.setActive(true);p.perform(2);QCOMPARE(p.activity(),QString("rest"));p.advanceTo(QDateTime::currentMSecsSinceEpoch()+1800000);QCOMPARE(p.needs()["energy"].toInt(),92);
        p.perform(2);QCOMPARE(p.activity(),QString("idle"));p.setActive(false);QVERIFY(!p.interacting());
    }
    void newEventsOnlyAndQuietMode(){
        HomeCompanion p;p.setOwner("a");p.celebrate("Game",{"One","Two"});QVERIFY(p.bubble().isEmpty());p.setActive(true);QCOMPARE(p.activity(),QString("celebrate"));QVERIFY(p.bubble().startsWith("2"));
        p.setOwner("b");QVERIFY(p.bubble().isEmpty());QCOMPARE(p.activity(),QString("idle"));p.perform(4);QVERIFY(p.quiet());p.celebrate("Game",{"Old"});QVERIFY(p.bubble().isEmpty());
    }
    void hintRoutesAndController(){
        HomeCompanion p;p.setOwner("a");p.setActive(true);p.begin();p.dispatch(Action::Right);QCOMPARE(p.focus(),2);p.dispatch(Action::Up);QCOMPARE(p.focus(),6);p.dispatch(Action::Confirm);QVERIFY(p.menuOpen());QCOMPARE(p.focus(),3);p.dispatch(Action::Down);QCOMPARE(p.focus(),4);p.dispatch(Action::Back);QVERIFY(!p.menuOpen());QVERIFY(p.interacting());p.dispatch(Action::Back);QVERIFY(!p.interacting());
        p.setNotifications({QVariantMap{{"id","notification-1"},{"unread",true}}});QCOMPARE(p.bubbleKind(),QString("notifications"));QSignalSpy inbox(&p,&HomeCompanion::inboxRequested);p.openHint();QCOMPARE(inbox.size(),1);QVERIFY(p.bubble().isEmpty());
        p.setNotifications({QVariantMap{{"id","notification-1"},{"unread",true}}});QVERIFY(p.bubble().isEmpty());
        p.setOwner("b");QVERIFY(p.bubble().isEmpty());
    }
    void playtimeReplacesPlayButton(){
        HomeCompanion p;p.setOwner("a");p.setActive(true);const auto before=p.needs()["mood"].toInt();
        p.perform(1);QCOMPARE(p.activity(),QString("idle"));QCOMPARE(p.needs()["mood"].toInt(),before);
        p.perform(0);QCOMPARE(p.needs()["mood"].toInt(),before);
        p.setActive(false);p.addGameplaySeconds(180);QCOMPARE(p.needs()["mood"].toInt(),before+5);
        p.addGameplaySeconds(-1);QCOMPARE(p.needs()["mood"].toInt(),before+5);
        p.addGameplaySeconds(3600);QCOMPARE(p.needs()["mood"].toInt(),100);
        p.setOwner("b");QCOMPARE(p.needs()["mood"].toInt(),80);
        p.setOwner("a");QCOMPARE(p.needs()["mood"].toInt(),100);
    }
};
QTEST_GUILESS_MAIN(HomeCompanionTests)
#include "HomeCompanionTests.moc"
