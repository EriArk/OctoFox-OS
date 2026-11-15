#pragma once
#include "features/trainer/ProfileInventory.h"
namespace trainer {
class ProfileInventoryFixture {
public:
    static void populate(ProfileInventory& inventory,int count=36) {
        inventory.items_.clear();inventory.visible_.clear();inventory.index_=0;inventory.preview_=true;
        inventory.search_.clear();inventory.filter_=inventory.sort_=0;inventory.control_=-1;
        const QStringList names{"Treecko","Torchic","Mudkip","Ralts","Aron","Swablu","Pikachu","Absol","Lotad"};
        const QStringList ids{"252","255","258","280","304","333","25","359","270"};
        for(int i=0;i<count;++i) {
            const int species=i%names.size();
            const QVariantList facts{
                QVariantMap{{"label","Level"},{"value",QString::number(12+i)}},
                QVariantMap{{"label","Sex"},{"value","Male"}},
                QVariantMap{{"label","Nature"},{"value","Hardy"}},
                QVariantMap{{"label","Ability"},{"value",i==0?"Overgrow":"Sample ability"}},
                QVariantMap{{"label","Held item"},{"value","None"}},
                QVariantMap{{"label","Origin"},{"value","Pokémon Emerald"}}};
            inventory.items_.append(QVariantMap{{"id","sample-"+QString::number(i)},{"title",names[species]},
                {"subtitle","Lv. "+QString::number(12+i)},{"level",12+i},{"game","Pokémon Emerald"},{"state",i==1?"listed":"stored"},
                {"image","image://sprite-detail/cuboid/v1/"+names[species].toLower()+"/"+ids[species]+"/pokedexDetailArt"},
                {"facts",facts},{"moves",QStringList{"Pound","Leer","Absorb","Quick Attack"}}});
        }
        inventory.rebuild();
    }
};
}
