#include "ExperienceNavigation.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QSet>

namespace trainer {
const ExperienceDescriptor& genericExperienceDescriptor() {
    static const ExperienceDescriptor value{"generic",2,"game-home",{}};
    return value;
}
bool ExperienceNavigation::valid(const ExperienceDescriptor& descriptor) {
    if(descriptor.id.isEmpty() || descriptor.version!=2 || descriptor.homeView.isEmpty())return false;
    if(descriptor.adapter.screens.isEmpty())return true;
    if(descriptor.adapter.label.isEmpty() || descriptor.adapter.icon.isEmpty())return false;
    QSet<QString> ids;
    QHash<QString,QString> groups;
    for(const auto& screen:descriptor.adapter.screens) {
        if(screen.id.isEmpty() || screen.label.isEmpty() || screen.view.isEmpty()
            || screen.icon.isEmpty() || ids.contains(screen.id))return false;
        ids.insert(screen.id);
        if(screen.group.isEmpty()!=screen.groupLabel.isEmpty())return false;
        if(groups.contains(screen.group) && groups[screen.group]!=screen.groupLabel)return false;
        groups.insert(screen.group,screen.groupLabel);
    }
    return true;
}
bool ExperienceNavigation::select(const QString& owner,const QString& adventure,
        const ExperienceDescriptor& descriptor,int revision) {
    const auto next=valid(descriptor)?descriptor:genericExperienceDescriptor();
    const bool changed=owner_!=owner || adventure_!=adventure || descriptor_!=next
        || registrationRevision_!=revision;
    if(!changed)return false;
    if(owner_!=owner)states_.clear();
    owner_=owner;adventure_=adventure;descriptor_=next;registrationRevision_=revision;++generation_;
    auto saved=states_.value(key());
    if(!screenIds().contains(saved["screen"].toString()))saved["screen"]=screenIds().value(0);
    states_.insert(key(),saved);
    return true;
}
bool ExperienceNavigation::current(const QString& owner,const QString& adventure,quint64 generation) const {
    return owner_==owner && adventure_==adventure && generation_==generation;
}
QString ExperienceNavigation::key() const {
    return QString::fromUtf8(QJsonDocument(QJsonArray{adventure_,descriptor_.id,descriptor_.version}).toJson(QJsonDocument::Compact));
}
QStringList ExperienceNavigation::screenIds() const {
    QStringList result;for(const auto& screen:descriptor_.adapter.screens)result.append(screen.id);return result;
}
QStringList ExperienceNavigation::groupIds() const {
    QStringList ids;for(const auto& s:descriptor_.adapter.screens) {
        const auto id=s.group.isEmpty()?QString("adapter"):s.group;
        if(!ids.contains(id))ids.append(id);
    }return ids;
}
QStringList ExperienceNavigation::groupLabels() const {
    QStringList ids,labels;for(const auto& s:descriptor_.adapter.screens) {
        const auto id=s.group.isEmpty()?QString("adapter"):s.group;
        if(!ids.contains(id)){ids.append(id);labels.append(s.groupLabel.isEmpty()?descriptor_.adapter.label:s.groupLabel);}
    }return labels;
}
QString ExperienceNavigation::group() const {
    for(const auto& s:descriptor_.adapter.screens)if(s.id==screen())return s.group.isEmpty()?QString("adapter"):s.group;
    return {};
}
QStringList ExperienceNavigation::groupScreens() const {
    QStringList ids;for(const auto& s:descriptor_.adapter.screens)
        if((s.group.isEmpty()?QString("adapter"):s.group)==group())ids.append(s.id);
    return ids;
}
bool ExperienceNavigation::showGroup(const QString& requested) {
    if(!groupIds().contains(requested))return false;
    const auto remembered=states_.value(key())["groups"].toObject()[requested].toString();
    QString first;
    for(const auto& s:descriptor_.adapter.screens)if((s.group.isEmpty()?QString("adapter"):s.group)==requested) {
        if(first.isEmpty())first=s.id;
        if(s.id==remembered)return show(s.id);
    }
    return show(first);
}
QString ExperienceNavigation::screen() const {
    const auto saved=states_.value(key())["screen"].toString();
    const auto ids=screenIds();return ids.contains(saved)?saved:ids.value(0);
}
int ExperienceNavigation::index() const {return screenIds().indexOf(screen());}
QString ExperienceNavigation::view() const {
    const auto selected=index();return selected>=0?descriptor_.adapter.screens[selected].view:QString();
}
bool ExperienceNavigation::show(const QString& screenId) {
    if(!screenIds().contains(screenId))return false;
    states_[key()].insert("screen",screenId);
    auto groups=states_[key()]["groups"].toObject();groups[group()]=screenId;
    states_[key()].insert("groups",groups);return true;
}
QJsonObject ExperienceNavigation::navigation() const {return states_.value(key())["navigation"].toObject();}
void ExperienceNavigation::rememberNavigation(const QJsonObject& navigation) {
    if(QJsonDocument(navigation).toJson(QJsonDocument::Compact).size()<=65536)
        states_[key()].insert("navigation",navigation);
}
QJsonObject ExperienceNavigation::state() const {
    QJsonObject entries;for(auto it=states_.cbegin();it!=states_.cend();++it)entries.insert(it.key(),it.value());
    return {{"version",2},{"owner",owner_},{"entries",entries}};
}
void ExperienceNavigation::restore(const QJsonObject& state) {
    states_.clear();++generation_;
    const auto version=state["version"].toInt();
    if((version!=1 && version!=2) || state["owner"].toString()!=owner_)return;
    const auto entries=state["entries"].toObject();
    for(auto it=entries.begin();it!=entries.end() && states_.size()<4096;++it) {
        if(it.key().size()>2048 || !it.value().isObject())continue;
        auto identity=QJsonDocument::fromJson(it.key().toUtf8()).array();
        if(identity.size()!=3 || !identity[0].isString() || !identity[1].isString())continue;
        if(identity[2].toInt()!=1 && identity[2].toInt()!=2)continue;
        identity[2]=2;
        const auto object=it.value().toObject();QJsonObject saved;
        const auto groups=object["groups"].toObject();
        if(!groups.isEmpty() && QJsonDocument(groups).toJson(QJsonDocument::Compact).size()<=8192)saved["groups"]=groups;
        for(const auto& name:{QString("screen"),QString("0"),QString("1")}) {
            if(!object.value(name).isString())continue;
            const auto value=object[name].toString();if(value.size()<=128)saved.insert(name,value);
        }
        if(saved.value("screen").toString().isEmpty() && saved.value("0").isString())saved["screen"]=saved.value("0");
        const auto navigation=object["navigation"].toObject();
        if(QJsonDocument(navigation).toJson(QJsonDocument::Compact).size()<=65536)saved.insert("navigation",navigation);
        states_.insert(QString::fromUtf8(QJsonDocument(identity).toJson(QJsonDocument::Compact)),saved);
    }
}
QString ExperienceNavigation::legacyScreen(int oldSlot) const {
    return oldSlot==0 || oldSlot==1?states_.value(key())[QString::number(oldSlot)].toString():QString();
}
void ExperienceNavigation::clear() {states_.clear();++generation_;}
}
