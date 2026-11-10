#include "features/social/BazaarCatalogue.h"
#include <QtTest>
#include <algorithm>
#include <QSignalSpy>

namespace trainer {
class BazaarCatalogueTests : public QObject {
    Q_OBJECT
    static QVariantList rooms() {
        QVariantList rows;
        for(int i=0;i<12;++i)rows.append(QVariantMap{{"id",QString::number(i)},{"title","Bazaar "+QString::number(i)},{"ownerName",i%2?"Mika":"Ren"},{"visitors",i}});
        return rows;
    }
private slots:
    void fixedOfficialAndTwoColumns() {
        BazaarCatalogue page;page.setPresentation(rooms(),{},{});
        page.dispatch(Action::Right);QCOMPARE(page.selectedIndex(),0);
        page.dispatch(Action::Right);QCOMPARE(page.selectedIndex(),1);
        page.dispatch(Action::Down);QCOMPARE(page.selectedIndex(),3);
        page.dispatch(Action::Left);QCOMPARE(page.selectedIndex(),2);
        page.dispatch(Action::Left);QCOMPARE(page.selection(),"official");
        page.dispatch(Action::Right);QCOMPARE(page.selectedIndex(),2);
        for(int i=0;i<10;++i)page.dispatch(Action::Down);
        QCOMPARE(page.selectedIndex(),10);
        page.dispatch(Action::Back);QCOMPARE(page.selection(),"official");
        QVERIFY(!page.dispatch(Action::Back));
    }
    void filtersOnlyPersonalPlacesAndKeepsStableIds() {
        BazaarCatalogue page;page.setPresentation(rooms(),{},{});
        page.focus("room:7");page.toggleFavorite("7");page.toggleFilter();
        QCOMPARE(page.rooms().size(),1);QCOMPARE(page.rooms()[0].toMap()["id"].toString(),"7");
        page.focus("room:7");page.applySearch("  REN  ");QVERIFY(page.rooms().isEmpty());
        page.activate("official");QCOMPARE(page.dialog(),"realms");page.closeDialog();
        page.applySearch("Mika");QCOMPARE(page.rooms().size(),1);
        page.focus("room:7");page.toggleFavorite("7");QVERIFY(page.rooms().isEmpty());QCOMPARE(page.selection(),"search");
        page.toggleFilter();QCOMPARE(page.rooms().size(),6);
        page.focus("room:7");auto reordered=rooms();std::reverse(reordered.begin(),reordered.end());
        page.setPresentation(reordered,{},{});QCOMPARE(page.selection(),"room:7");
        for(int i=0;i<reordered.size();++i)if(reordered[i].toMap()["id"]=="7"){reordered.removeAt(i);break;}
        page.setPresentation(reordered,{},{});QCOMPARE(page.selection(),"official");
    }
    void ownerAndRestoreNeverRestoreSession() {
        BazaarCatalogue page;page.setOwner("one");page.setPresentation(rooms(),{},{});
        page.focus("room:4");page.toggleFavorite("4");page.setScroll(185);
        auto state=page.navigation();page.activate("official");QVERIFY(!page.dialog().isEmpty());
        page.restore(state);QCOMPARE(page.selection(),"room:4");QCOMPARE(page.scroll_,185.0);QVERIFY(page.dialog().isEmpty());
        page.setOwner("two");QCOMPARE(page.selection(),"official");QVERIFY(page.rooms().isEmpty());
        QVERIFY(page.favorites_.isEmpty());QCOMPARE(page.scroll_,0.0);QVERIFY(page.dialog().isEmpty());
    }
    void emptyDisconnectedAndUnavailableActions() {
        BazaarCatalogue page;QSignalSpy notice(&page,&BazaarCatalogue::notice);
        page.setConnectionState("signed-out");QVERIFY(page.status().contains("Sign in"));
        page.activate("official");QCOMPARE(page.dialog(),"realms");QVERIFY(page.realms().isEmpty());
        page.dispatch(Action::NextFace);QCOMPARE(page.dialog(),"realms");
        page.dispatch(Action::Back);page.activate("create");QCOMPARE(page.dialog(),"create");
        page.dispatch(Action::Confirm);QCOMPARE(page.dialog(),"create");page.closeDialog();QCOMPARE(notice.count(),0);
        page.setPresentation(rooms(),{QVariantMap{{"name","Veyr"},{"visitors",32},{"capacity",32}},QVariantMap{{"name","Keth"},{"visitors",3},{"capacity",32}}},{});
        page.activate("official");page.chooseRealm(0);QCOMPARE(notice.count(),0);
        page.chooseRealm(1);QCOMPARE(notice.count(),1);QVERIFY(notice[0][0].toString().contains("not available"));
        page.closeDialog();page.activate("room:0");QCOMPARE(page.dialog(),"details");QCOMPARE(notice.count(),1); // zero visitors is still a place
        page.closeDialog();page.activate("room:missing");QCOMPARE(notice.count(),1);
    }
};
}
QTEST_GUILESS_MAIN(trainer::BazaarCatalogueTests)
#include "BazaarCatalogueTests.moc"
