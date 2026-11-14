#pragma once
#include "features/social/BazaarCatalogue.h"

namespace trainer {
// Isolated scrolling/occupancy fixture. The normal product has only the two
// owner-requested, explicitly labelled Mika/Ren previews and no fake occupancy.
class BazaarFixture {
public:
    static void useProvider(BazaarCatalogue& page) { page.fixture_=false;page.all_.clear();page.rebuild();page.refresh(); }
    static void populate(BazaarCatalogue& page) {
        QVariantList rows;
        const QStringList names{"Mika","Ren","Kai","Nia","Sol","Ash","Lumi","Rin","Taro","Emi","Zed","Noa","Ivo","Mio"};
        const QStringList covers{"qrc:/bazaar/official.png","qrc:/profile-scenes/aurora.png","qrc:/profile-scenes/dusk.png","qrc:/profile-scenes/orbit.png"};
        for(int i=0;i<names.size();++i)rows.append(QVariantMap{{"id",QString::number(i)},{"title",names[i]+"'s Bazaar"},{"ownerName",names[i]},{"visitors",i==2?0:i%9+1},{"cover",covers[i%4]}});
        page.setPresentation(rows,{QVariantMap{{"name","Veyr"},{"visitors",12},{"capacity",32}},QVariantMap{{"name","Keth"},{"visitors",28},{"capacity",32}},QVariantMap{{"name","Oryn"},{"visitors",32},{"capacity",32}}},"Test directory");
    }
    static void clear(BazaarCatalogue& page,QString status) {page.setPresentation({}, {},status);}
};
}
