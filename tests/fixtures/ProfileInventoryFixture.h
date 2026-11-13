#pragma once
#include "features/trainer/ProfileInventory.h"
namespace trainer {
class ProfileInventoryFixture {
public:
    static void populate(ProfileInventory& inventory) {
        inventory.items_.clear();inventory.index_=0;inventory.detail_=false;inventory.preview_=true;
        const QStringList names{"Treecko","Torchic","Mudkip","Ralts","Aron","Swablu","Pikachu","Absol","Lotad"};
        const QStringList ids{"252","255","258","280","304","333","25","359","270"};
        for(int i=0;i<names.size();++i) {
            const QVariantList facts{
                QVariantMap{{"label","Level"},{"value",QString::number(12+i)}},
                QVariantMap{{"label","Sex"},{"value","Male"}},
                QVariantMap{{"label","Nature"},{"value","Hardy"}},
                QVariantMap{{"label","Ability"},{"value",i==0?"Overgrow":"Sample ability"}},
                QVariantMap{{"label","Held item"},{"value","None"}},
                QVariantMap{{"label","Origin"},{"value","Pokémon Emerald"}}};
            inventory.items_.append(QVariantMap{{"id","sample-"+QString::number(i)},{"title",names[i]},
                {"subtitle","Lv. "+QString::number(12+i)},{"game","Pokémon Emerald"},{"state",i==1?"listed":"stored"},
                {"image","image://sprite-detail/cuboid/v1/"+names[i].toLower()+"/"+ids[i]+"/pokedexDetailArt"},
                {"facts",facts},{"moves",QStringList{"Pound","Leer","Absorb","Quick Attack"}}});
        }
        emit inventory.changed();
    }
};
}
