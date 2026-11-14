#include "features/apps/AppsController.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QJsonObject>
#include <QJsonArray>
#include <QSignalSpy>
#include <QFile>
#include <QStandardPaths>
using namespace trainer;
class AppsTests:public QObject {
    Q_OBJECT
    static void seed(AppsController& apps) {
        apps.accept({{"event","catalogue"},{"rows",QJsonArray{
            QJsonObject{{"id","z.desktop"},{"name","Writer"}},
            QJsonObject{{"id","a.desktop"},{"name","Calculator"}},
            QJsonObject{{"id","a.desktop"},{"name","Duplicate"}}}}});
        apps.accept({{"event","ready"}});
    }
private slots:
    void managedGamesUseGameLifecycleAndStayInQuickApps() {
        AppsController apps;QString requested;int launches=0;
        apps.launchManagedGame=[&](const QString& id){requested=id;++launches;return QString();};
        apps.launchGuard=[]{return QString("Ordinary apps blocked during game");};
        apps.accept({{"event","catalogue"},{"rows",QJsonArray{QJsonObject{{"id","game.desktop"},{"name","Game"},{"gameId","steam:42"}}}}});
        QSignalSpy commands(&apps,&AppsController::commandRequested);
        apps.open(0);QCOMPARE(requested,"steam:42");QVERIFY(commands.isEmpty());
        apps.setGameState({{"id","game:steam:42"},{"gameId","steam:42"},{"name","Game"}},true);
        QCOMPARE(apps.rail().size(),1);QVERIFY(apps.rail().first().toMap()["minimized"].toBool());
        apps.accept({{"event","state"},{"running",QJsonArray{}},{"current",""}});QCOMPARE(apps.rail().size(),1);
        apps.open(0,true);QCOMPARE(launches,2);
        apps.setGameState({},false);QVERIFY(apps.rail().isEmpty());
        apps.setGameState({{"id","game:crates:fixture"},{"gameId","crates:fixture"},{"name","Crate game"}},true);
        QCOMPARE(apps.rail().size(),1);apps.open(0,true);QCOMPARE(requested,"crates:fixture");
        apps.setGameState({},false);QVERIFY(apps.rail().isEmpty());
    }
    void helperCrashReconnectsAndRestoresQuickApps() {
        const auto python=QStandardPaths::findExecutable("python3");if(python.isEmpty())QSKIP("Python3 unavailable");
        QTemporaryDir dir;const auto helper=dir.filePath("helper.py");
        QFile file(helper);QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(R"PY(import json, pathlib, sys, time
marker=pathlib.Path(__file__).with_suffix('.started')
first=not marker.exists()
marker.touch()
def send(**value): print(json.dumps(value),flush=True)
send(event='catalogue',rows=[dict(id='fixture.desktop',name='Fixture')])
send(event='ready')
send(event='state',running=['fixture.desktop'],current='',launching='')
if first:
    time.sleep(.3)
    sys.exit(1)
for line in sys.stdin: pass
)PY");file.close();
        AppsController apps;apps.start(python,helper);
        QTRY_VERIFY(apps.ready());QCOMPARE(apps.rail().size(),1);
        QTRY_VERIFY(!apps.ready());QCOMPARE(apps.rail().size(),1);
        QTRY_VERIFY_WITH_TIMEOUT(apps.ready(),5000);
        QCOMPARE(apps.rail().size(),1);QVERIFY(apps.rail().first().toMap()["minimized"].toBool());
    }
    void browserUsesManagedLaunchAndReportsFailure() {
        QTemporaryDir dir;AppsController apps;apps.configure(dir.path(),"alice");
        QSignalSpy commands(&apps,&AppsController::commandRequested),errors(&apps,&AppsController::webOpenFailed);
        QVERIFY(!apps.openWebUrl(QUrl("https://example.com/login")));seed(apps);commands.clear();
        for(const auto& url:{"file:///tmp/test","http://example.com/login","https://user:secret@example.com/"})QVERIFY(!apps.openWebUrl(QUrl(url)));
        apps.launchGuard=[]{return QString("Game owns input");};QVERIFY(!apps.openWebUrl(QUrl("https://example.com/login")));
        apps.launchGuard={};QVERIFY(apps.openWebUrl(QUrl("https://example.com/login?a=1")));
        QCOMPARE(commands.size(),1);QCOMPARE(commands[0][0].toJsonObject()["command"].toString(),"open-url");
        QVERIFY(!apps.openWebUrl(QUrl("https://example.com/duplicate")));
        apps.accept({{"event","error"},{"message","Browser unavailable"}});QCOMPARE(errors.size(),1);
        QVERIFY(apps.openWebUrl(QUrl("https://example.com/retry")));
        apps.accept({{"event","foreground"},{"id","browser.desktop"},{"pid","123"}});
        apps.control(1);QCOMPARE(commands.last()[0].toJsonObject()["command"].toString(),"minimize");
        apps.accept({{"event","shell"}});QVERIFY(apps.current().isEmpty());
        apps.accept({{"event","error"},{"message","Unrelated error"}});QCOMPARE(errors.size(),1);
    }
    void setupBrowserPermissionDoesNotUnlockOrdinaryApps() {
        AppsController apps;seed(apps);QSignalSpy commands(&apps,&AppsController::commandRequested);
        apps.launchGuard=[]{return QString("Setup is active");};
        apps.webLaunchGuard=[]{return QString();};
        apps.open(0);QVERIFY(commands.isEmpty());
        QVERIFY(apps.openWebUrl(QUrl("https://example.com/login")));QCOMPARE(commands.size(),1);
        apps.accept({{"event","error"},{"message","Test complete"}});
        apps.webLaunchGuard=[]{return QString("Setup account page was closed");};
        QVERIFY(!apps.openWebUrl(QUrl("https://example.com/login")));QCOMPARE(commands.size(),1);
    }
    void browserRestartsStoppedHelperAndWaitsForReadiness() {
        AppsController apps;QSignalSpy commands(&apps,&AppsController::commandRequested),errors(&apps,&AppsController::webOpenFailed);
        apps.start("traineros-missing-test-executable","fixture");QTRY_VERIFY(apps.status().contains("stopped"));
        QVERIFY(apps.openWebUrl(QUrl("https://example.com/recovery")));QVERIFY(commands.isEmpty());
        apps.accept({{"event","ready"}});QCOMPARE(commands.size(),1);
        QCOMPARE(commands.last()[0].toJsonObject()["url"],"https://example.com/recovery");
        QTRY_COMPARE(errors.size(),1);
        QVERIFY(apps.openWebUrl(QUrl("https://example.com/retry")));
        apps.launchGuard=[]{return QString("Game started while connecting");};apps.accept({{"event","ready"}});
        QCOMPARE(commands.size(),1);QCOMPARE(errors.size(),2);
    }
    void leavingForAnotherPrimaryPreservesBrowsingModeAndFocus() {
        QTemporaryDir dir;AppsController apps;apps.configure(dir.path(),"alice");seed(apps);
        apps.select(1);apps.leave(true);QCOMPARE(apps.focusIndex(),1);
        apps.options(1);apps.menuAction(0);apps.select(0,true);
        apps.leave(true);QVERIFY(apps.railFocused());QCOMPARE(apps.focusIndex(),0);
        apps.showHidden();apps.leave(true);QVERIFY(apps.hiddenView());
        apps.leave();QVERIFY(!apps.hiddenView());QVERIFY(!apps.railFocused());
    }
    void pinnedAndRunningAreSeparateWithoutDuplicates() {
        QTemporaryDir dir;AppsController apps;apps.configure(dir.path(),"alice");seed(apps);
        apps.options(1);apps.menuAction(0); // Writer sorts after Calculator but is pinned first.
        apps.accept({{"event","state"},{"running",QJsonArray{"a.desktop","z.desktop"}},{"current",""}});
        QVERIFY(apps.hasRunningApps()); // Minimized windows still prevent a destructive session handoff.
        const auto rail=apps.rail();QCOMPARE(rail.size(),2);
        QCOMPARE(rail[0].toMap()["id"].toString(),"z.desktop");
        QVERIFY(rail[0].toMap()["railPinned"].toBool());QVERIFY(rail[0].toMap()["running"].toBool());
        QCOMPARE(rail[1].toMap()["id"].toString(),"a.desktop");QVERIFY(!rail[1].toMap()["railPinned"].toBool());
        apps.select(0,true);apps.options(0,true);apps.menuAction(0);
        QCOMPARE(apps.rail()[apps.focusIndex()].toMap()["id"].toString(),"z.desktop");
        apps.accept({{"event","state"},{"running",QJsonArray{"z.desktop"}},{"current",""}});
        QCOMPARE(apps.focusIndex(),0);QCOMPARE(apps.rail().size(),1);
    }
    void favoriteCapacityBlocksNewPinsWithoutDeletingSavedFavorites() {
        QTemporaryDir dir;AppsController apps;apps.configure(dir.path(),"alice");seed(apps);
        apps.setFavoriteCapacity(1);apps.options(0);apps.menuAction(0);
        apps.options(1);apps.menuAction(0);
        QCOMPARE(apps.rail().size(),1);QVERIFY(!apps.rows()[1].toMap()["favorite"].toBool());
        QVERIFY(apps.status().contains("full"));QVERIFY(!apps.menu().isEmpty());
        apps.setFavoriteCapacity(2);apps.menuAction(0);QCOMPARE(apps.rail().size(),2);
        apps.setFavoriteCapacity(1);QCOMPARE(apps.rail().size(),1);
        QVERIFY(apps.rows()[1].toMap()["favorite"].toBool());
        AppsController reopened;reopened.configure(dir.path(),"alice");seed(reopened);
        QCOMPARE(reopened.rail().size(),2);
    }
    void runningFavoritesSurviveCapacityAndMinimizeWithoutDuplicates() {
        QTemporaryDir dir;AppsController apps;apps.configure(dir.path(),"alice");seed(apps);
        apps.options(0);apps.menuAction(0);apps.options(1);apps.menuAction(0);
        apps.setFavoriteCapacity(0);
        apps.accept({{"event","state"},{"running",QJsonArray{"a.desktop","z.desktop"}},{"current","a.desktop"}});
        QCOMPARE(apps.rail().size(),2);
        QVERIFY(!apps.rail()[0].toMap()["railPinned"].toBool());
        QVERIFY(!apps.rail()[0].toMap()["minimized"].toBool());
        QVERIFY(apps.rail()[1].toMap()["minimized"].toBool());
        apps.accept({{"event","shell"}});
        QVERIFY(apps.rail()[0].toMap()["minimized"].toBool());
        apps.setFavoriteCapacity(2);QCOMPARE(apps.rail().size(),2);
        QVERIFY(apps.rail()[0].toMap()["railPinned"].toBool());
        apps.accept({{"event","state"},{"running",QJsonArray{}},{"current",""}});
        QVERIFY(!apps.rail()[0].toMap()["running"].toBool());
    }
    void launchStateIsImmediateAndErrorsReachTheOrigin() {
        AppsController apps;seed(apps);QSignalSpy commands(&apps,&AppsController::commandRequested),errors(&apps,&AppsController::launchFailed);
        apps.open(0);apps.open(0);QCOMPARE(commands.size(),1);
        QVERIFY(apps.rows()[0].toMap()["launching"].toBool());QCOMPARE(apps.rail().size(),1);
        apps.accept({{"event","error"},{"message","Window unavailable"}});
        QCOMPARE(errors.size(),1);QVERIFY(!apps.rows()[0].toMap()["launching"].toBool());QVERIFY(apps.rail().isEmpty());
        apps.openDesktopId("a.desktop");QVERIFY(apps.rows()[0].toMap()["launching"].toBool());
        apps.accept({{"event","foreground"},{"id","a.desktop"}});
        QVERIFY(apps.rows()[0].toMap()["running"].toBool());QVERIFY(!apps.rows()[0].toMap()["launching"].toBool());
        apps.accept({{"event","controls"}});
        apps.accept({{"event","action"},{"action","home"}});
        QCOMPARE(commands.last()[0].toJsonObject()["command"].toString(),"resume");
        QVERIFY(!apps.controlsOpen());
    }
    void catalogueRefreshKeepsTheSelectedApplication() {
        AppsController apps;seed(apps);apps.select(1);
        apps.accept({{"event","catalogue"},{"rows",QJsonArray{
            QJsonObject{{"id","new.desktop"},{"name","Browser"}},
            QJsonObject{{"id","a.desktop"},{"name","Calculator"}},
            QJsonObject{{"id","z.desktop"},{"name","Writer"}}}}});
        QCOMPARE(apps.rows()[apps.focusIndex()].toMap()["id"].toString(),"z.desktop");
    }
    void unavailableFileAndCratesLaunchAreVisibleFailures() {
        AppsController apps;QSignalSpy errors(&apps,&AppsController::launchFailed);
        apps.openFile("file:///tmp/example.txt");apps.openDesktopId("example.desktop");
        QCOMPARE(errors.size(),2);QVERIFY(!apps.hasRunningApps());
    }
    void emptyQuickTrayNeverLaunchesTheUnderlyingGrid() {
        AppsController apps;seed(apps);QSignalSpy commands(&apps,&AppsController::commandRequested);
        apps.focusRail();apps.dispatch(Action::Confirm,true);apps.dispatch(Action::LocalAction,true);
        QVERIFY(commands.isEmpty());QVERIFY(apps.menu().isEmpty());
        apps.accept({{"event","state"},{"running",QJsonArray{"a.desktop","z.desktop"}},{"current",""}});
        apps.focusRail();apps.dispatch(Action::Right,true);QCOMPARE(apps.focusIndex(),1);
        apps.dispatch(Action::Confirm,true);QCOMPARE(commands.last()[0].toJsonObject()["id"],"z.desktop");
        apps.accept({{"event","state"},{"running",QJsonArray{}},{"current",""}});commands.clear();
        apps.dispatch(Action::Confirm,true);QVERIFY(commands.isEmpty());
    }
    void preferencesArePerTrainerAndSurviveReopen() {
        QTemporaryDir dir;AppsController apps;apps.configure(dir.path(),"alice");seed(apps);
        QCOMPARE(apps.rows().size(),2);QCOMPARE(apps.rows()[0].toMap()["name"].toString(),"Calculator");
        apps.options(0);apps.menuAction(0);QCOMPARE(apps.rail().size(),1);
        apps.options(0);apps.menuAction(1);QCOMPARE(apps.rows().size(),1);QVERIFY(apps.rail().isEmpty());
        AppsController reopened;reopened.configure(dir.path(),"alice");seed(reopened);
        QCOMPARE(reopened.rows().size(),1);reopened.showHidden();QCOMPARE(reopened.rows().size(),1);
        QVERIFY(reopened.rows()[0].toMap()["favorite"].toBool());
        reopened.options(0);reopened.menuAction(1);reopened.showHidden();QCOMPARE(reopened.rows().size(),2);
        reopened.configure(dir.path(),"bob");QCOMPARE(reopened.rows().size(),2);QVERIFY(reopened.rail().isEmpty());
    }
    void hiddenRunningAppRemainsReachable() {
        QTemporaryDir dir;AppsController apps;apps.configure(dir.path(),"alice");seed(apps);
        apps.options(0);apps.menuAction(1);
        apps.accept({{"event","state"},{"running",QJsonArray{"a.desktop"}},{"current",""}});
        QCOMPARE(apps.rows().size(),1);QCOMPARE(apps.rail().size(),1);
        QSignalSpy commands(&apps,&AppsController::commandRequested);
        apps.dispatch(Action::ToggleContinue);apps.dispatch(Action::Confirm);
        QCOMPARE(commands.last()[0].toJsonObject()["id"].toString(),"a.desktop");
        apps.accept({{"event","state"},{"running",QJsonArray{}},{"current",""}});
        QVERIFY(apps.rail().isEmpty());QVERIFY(!apps.railFocused());
    }
    void launchGuardAndOrdinaryCloseCommands() {
        AppsController apps;seed(apps);QSignalSpy commands(&apps,&AppsController::commandRequested);
        apps.launchGuard=[] {return QString("Game is running");};apps.open(0);QVERIFY(commands.isEmpty());
        QCOMPARE(apps.status(),"Game is running");apps.launchGuard={};apps.open(0);
        QCOMPARE(commands.last()[0].toJsonObject()["command"].toString(),"launch");
        QSignalSpy hide(&apps,&AppsController::foregroundRequested),show(&apps,&AppsController::shellRequested);
        apps.accept({{"event","foreground"},{"id","a.desktop"}});QCOMPARE(hide.size(),1);
        apps.accept({{"event","controls"}});apps.control(1);
        QCOMPARE(commands.last()[0].toJsonObject()["command"].toString(),"minimize");
        apps.accept({{"event","shell"}});QCOMPARE(show.size(),1);QVERIFY(apps.current().isEmpty());
        apps.accept({{"event","foreground"},{"id","a.desktop"}});apps.control(2);
        QCOMPARE(commands.last()[0].toJsonObject()["command"].toString(),"close");
        QVERIFY(!apps.current().isEmpty()); // A request is not confirmation of exit.
    }
    void failedPreferenceWriteDoesNotPretendSuccess() {
        AppsController apps;seed(apps);apps.options(0);apps.menuAction(1);
        QCOMPARE(apps.rows().size(),2);QVERIFY(!apps.status().isEmpty());
    }
};
QTEST_GUILESS_MAIN(AppsTests)
#include "AppsTests.moc"
