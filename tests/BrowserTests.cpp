#include "features/browser/BrowserController.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QSignalSpy>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include "platform/files/FilesService.h"
using namespace trainer;
class BrowserTests:public QObject {
    Q_OBJECT
private slots:
    void dialogsKeepOriginAndResolveOnlyOnce() {
        BrowserController b;const auto tab=b.newTab();QSignalSpy finished(&b,&BrowserController::dialogFinished);
        const int id=b.requestDialog(tab,"prompt","https://user:secret@example.org/path?token=private","Question","original");
        QVERIFY(id>0);QCOMPARE(b.dialog()["origin"].toString(),QString("https://example.org"));
        b.editDialogText();b.applyText("new response");QCOMPARE(b.dialog()["text"].toString(),QString("new response"));QVERIFY(finished.isEmpty());
        b.answerDialog(true);b.answerDialog(true);QCOMPARE(finished.size(),1);QCOMPARE(finished[0][0].toInt(),id);
        QVERIFY(finished[0][1].toBool());QCOMPARE(finished[0][2].toStringList(),QStringList{"new response"});QVERIFY(b.dialog().isEmpty());
    }
    void dialogsCancelOnTabOwnerAndNavigationChanges() {
        QTemporaryDir dir;BrowserController b;b.configure(dir.path(),"one");auto tab=b.selected();QSignalSpy finished(&b,&BrowserController::dialogFinished);
        auto id=b.requestDialog(tab,"prompt","https://example.org","Question","old");b.editDialogText();
        const auto other=b.newTab();QCOMPARE(finished.size(),1);QVERIFY(!finished.last()[1].toBool());
        b.applyText("late answer");QVERIFY(b.dialog().isEmpty());
        QCOMPARE(b.requestDialog(tab,"prompt","","background"),0);
        const auto next=b.requestDialog(other,"confirm","","New request");b.cancelDialog(id);QCOMPARE(b.dialog()["id"].toInt(),next);
        b.openUrl("about:blank");QVERIFY(b.dialog().isEmpty()); // No Chromium in this QCoreApplication test.
        b.requestDialog(other,"prompt","","Question");b.configure(dir.path(),"two");QVERIFY(b.dialog().isEmpty());
        b.requestDialog(b.selected(),"confirm","","Question");b.closeTab(b.selected());QVERIFY(b.dialog().isEmpty());
        QCOMPARE(finished.size(),4);for(const auto& row:finished)QVERIFY(!row[1].toBool());
    }
    void uploadFiltersMultiSelectionAndCancellation() {
        QTemporaryDir dir;QDir().mkpath(dir.path()+"/nested");
        for(const auto& name:{"one.txt","two.png","nested/three.txt"}){QFile f(dir.filePath(name));QVERIFY(f.open(QIODevice::WriteOnly));f.write("fixture");}
        BrowserController b;const auto tab=b.newTab();QSignalSpy finished(&b,&BrowserController::dialogFinished);
        b.requestDialog(tab,"files","https://example.org","",{},QStringList{"text/plain"});auto p=b.picker();p->navigate(dir.path());QTRY_VERIFY(!p->busy());
        auto index=[&](QString name){const auto rows=p->rows();for(int i=0;i<rows.size();++i)if(rows[i].toMap()["title"]==name)return i;return -1;};
        QVERIFY(!p->rows()[index("two.png")].toMap()["allowed"].toBool());
        p->activate(index("two.png"),"list");QVERIFY(!p->canChoose());
        p->activate(index("one.txt"),"list");QVERIFY(p->canChoose());
        p->select(index("two.png"));QVERIFY(p->canChoose()); // Focus does not toggle a multi-selection.
        p->navigate(dir.path()+"/nested");QTRY_VERIFY(!p->busy());p->activate(index("three.txt"),"list");p->choose();
        QCOMPARE(finished.size(),1);QVERIFY(finished[0][1].toBool());QCOMPARE(finished[0][2].toStringList(),(QStringList{dir.filePath("one.txt"),dir.filePath("nested/three.txt")}));
        b.requestDialog(tab,"file","","",{},QStringList{".txt"});p->navigate(dir.path());QTRY_VERIFY(!p->busy());p->select(index("one.txt"));
        QVERIFY(QFile::remove(dir.filePath("one.txt")));p->choose();QVERIFY(p->isOpen());QVERIFY(!p->error().isEmpty());QCOMPARE(finished.size(),1);
        p->cancel();QCOMPARE(finished.size(),2);QVERIFY(!finished.last()[1].toBool());
        p->begin(dir.path(),true);QTRY_VERIFY(!p->busy());QVERIFY(!p->multiple());QVERIFY(p->canChoose());p->cancel();
    }
    void completedDownloadMovesWithoutReplacingExistingFile() {
        FilesService files;if(!files.available())QSKIP("Linux libfm backend required");
        QTemporaryDir temp;QDir().mkpath(temp.path()+"/target");
        const auto source=temp.path()+"/one.txt",target=temp.path()+"/target/one.txt";
        const auto write=[](QString path,QByteArray text){QFile f(path);return f.open(QIODevice::WriteOnly)&&f.write(text)==text.size();};
        QVERIFY(write(source,"download"));QVERIFY(write(target,"keep"));QString state;
        {BrowserController b;b.configure(temp.path(),"test");state=b.storagePath();}
        QVERIFY(write(state+"/downloads.json",QJsonDocument(QJsonArray{QJsonObject{{"id","one"},{"name","one.txt"},{"path",source},{"state","done"}}}).toJson()));
        {BrowserController b;b.configure(temp.path(),"test");b.setFilesService(&files);b.setDownloadDestination("one",temp.path()+"/target");
            QTRY_COMPARE(b.downloads()[0].toMap()["state"].toString(),"done");
            QTRY_VERIFY(!QFile::exists(source));QTRY_VERIFY(b.downloads()[0].toMap()["path"].toString().endsWith("one (1).txt"));
        }
        QFile original(target);QVERIFY(original.open(QIODevice::ReadOnly));QCOMPARE(original.readAll(),QByteArray("keep"));
        BrowserController restored;restored.configure(temp.path(),"test");QVERIFY(restored.downloads()[0].toMap()["path"].toString().endsWith("one (1).txt"));
    }
    void interruptedDownloadRetainsChosenFolder() {
        QTemporaryDir temp;QString state;
        {BrowserController b;b.configure(temp.path(),"test");state=b.storagePath();}
        QFile f(state+"/downloads.json");QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(QJsonDocument(QJsonArray{QJsonObject{{"id","one"},{"name","one.txt"},{"path",temp.path()+"/one.txt"},{"state","queued"},{"destination",temp.path()+"/target"}}}).toJson());f.close();
        BrowserController b;b.configure(temp.path(),"test");QCOMPARE(b.downloads()[0].toMap()["destination"].toString(),temp.path()+"/target");
        QCOMPARE(b.downloads()[0].toMap()["state"].toString(),"error");QVERIFY(b.downloads()[0].toMap()["terminal"].toBool());
    }
    void mouseButtonsKeepBackAndToolbarSeparate(){
        BrowserController browser;QSignalSpy commands(&browser,&BrowserController::commandRequested);
        browser.dispatch(Action::Confirm);browser.dispatch(Action::ChangeView);
        browser.dispatch(Action::Back);browser.dispatch(Action::LocalAction);
        QCOMPARE(commands.size(),4);
        QCOMPARE(commands[0][0].toString(),"click");QCOMPARE(commands[1][0].toString(),"context");
        QCOMPARE(commands[2][0].toString(),"back");QCOMPARE(commands[3][0].toString(),"chrome");
    }
    void navigationBoundary(){
        QCOMPARE(BrowserController::navigationUrl("example.com"),QString("https://example.com"));
        QCOMPARE(BrowserController::navigationUrl("https://example.com/path?q=a"),QString("https://example.com/path?q=a"));
        QVERIFY(BrowserController::navigationUrl("two words").contains("q=two%20words"));
        for(const auto& value:{"javascript:alert(1)","file:///etc/passwd","https://name:secret@example.com/","data:text/html,test"})QVERIFY2(BrowserController::navigationUrl(value).isEmpty(),value);
    }
    void sessionAndOwnerIsolation(){
        QTemporaryDir directory;QString first,selected;
        {BrowserController browser;browser.configure(directory.path(),"one");first=browser.storagePath();browser.newTab("https://example.com/");selected=browser.selected();browser.updateTab(selected,"https://example.com/","Example","",true);browser.toggleBookmark("https://example.com/","Example");}
        {BrowserController browser;browser.configure(directory.path(),"one");QCOMPARE(browser.tabs().size(),2);QVERIFY(browser.selected()!=selected);QCOMPARE(browser.tabs().first().toMap()["url"].toString(),QString("about:blank"));QCOMPARE(browser.bookmarks().size(),1);QCOMPARE(browser.history().size(),1);
            browser.enter();QVERIFY(!browser.profile()); // Dashboard never starts Chromium.
            browser.configure(directory.path(),"two");QVERIFY(browser.storagePath()!=first);QCOMPARE(browser.tabs().size(),1);QVERIFY(browser.bookmarks().isEmpty());QVERIFY(browser.history().isEmpty());
            browser.configure(directory.path(),"one");QVERIFY(browser.selected()!=selected);QCOMPARE(browser.tabs().size(),2);QCOMPARE(browser.bookmarks().size(),1);}
    }
    void lastTabAndBookmarkToggle(){BrowserController browser;browser.newTab();auto id=browser.selected();browser.closeTab(id);QCOMPARE(browser.tabs().size(),1);QVERIFY(browser.selected()!=id);browser.toggleBookmark("https://example.com/","Example");browser.toggleBookmark("https://example.com/","Example");QVERIFY(browser.bookmarks().isEmpty());}
    void historyDeduplicatesAndUnsafeRestore(){QTemporaryDir directory;{BrowserController browser;browser.configure(directory.path(),"one");auto id=browser.selected();browser.updateTab(id,"https://example.com/","First","",true);browser.updateTab(id,"https://example.com/","Second","",true);QCOMPARE(browser.history().size(),1);browser.updateTab(id,"blob:https://example.com/private","Blob","",false);}BrowserController restored;restored.configure(directory.path(),"one");QCOMPARE(restored.tabs().first().toMap()["url"].toString(),QString("about:blank"));}
    void localActionsAreSeparate(){BrowserController browser;QSignalSpy commands(&browser,&BrowserController::commandRequested);for(const auto action:{Action::PreviousFace,Action::NextFace,Action::Secondary,Action::ToggleContinue,Action::SystemMenu})browser.dispatch(action);QCOMPARE(commands.size(),0);browser.dispatch(Action::LocalAction);QCOMPARE(commands.takeFirst().first().toString(),QString("chrome"));browser.dispatch(Action::ContextMenu);QCOMPARE(commands.takeFirst().first().toString(),QString("context"));}
};
QTEST_GUILESS_MAIN(BrowserTests)
#include "BrowserTests.moc"
