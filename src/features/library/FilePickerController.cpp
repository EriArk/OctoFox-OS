#include "FilePickerController.h"
#include <QDir>
#include <QFileInfo>
#include <QMimeDatabase>
#include <algorithm>
#include <memory>

namespace trainer {
QVariantList FilePickerController::rows() const {
    QVariantList result;
    for(const auto& e:current_.entries)result.append(QVariantMap{{"id",e.path},{"title",e.name},{"directory",e.directory},
        {"icon",e.icon.isEmpty()?(e.directory?"folder":"file"):e.icon},{"size",e.sizeLabel},{"modified",e.modified},
        {"checked",selectedPaths_.contains(e.path)},{"allowed",e.directory||(!chooseFolder_&&allowed(e.path))}});
    return result;
}
QVariantList FilePickerController::breadcrumbs() const {
    QVariantList result;
    if(current_.path.isEmpty())return result;
    auto dir=QDir(current_.path);
    for(int i=0;i<128;++i) {
        const auto path=dir.absolutePath();
        result.prepend(QVariantMap{{"path",path},{"title",path==QDir::homePath()?"Home":dir.isRoot()?path:dir.dirName()}});
        if(path==QDir::homePath() || dir.isRoot() || !dir.cdUp())break;
    }
    return result;
}
bool FilePickerController::canChoose() const {
    return open_ && !busy_ && current_.error.isEmpty() && (chooseFolder_?!current_.path.isEmpty():multiple_?!selectedPaths_.isEmpty():!selectedPath_.isEmpty());
}
QString FilePickerController::selectionName() const {
    if(multiple_)return selectedPaths_.isEmpty()?QString("Select files · confirm to toggle"):QString("%1 files selected").arg(selectedPaths_.size());
    return chooseFolder_?(QFileInfo(current_.path).fileName().isEmpty()?current_.path:QFileInfo(current_.path).fileName()):QFileInfo(selectedPath_).fileName();
}
void FilePickerController::begin(const QString& folder,bool chooseFolder) {
    multiple_=false;types_.clear();selectedPaths_.clear();
    chooseFolder_=chooseFolder;open_=true;history_.clear();places_.clear();place_=0;
    const auto token=++placesGeneration_;
    if(catalog_)catalog_->list({},0,this,[this,token](const DirectoryPage& result){
        if(!open_||token!=placesGeneration_)return;
        for(const auto& e:result.entries)places_.append(QVariantMap{{"path",e.path},{"title",e.name},{"icon",e.icon.isEmpty()?"drive-harddisk":e.icon}});
        emit changed();
    });
    load(folder.isEmpty()?QDir::homePath():folder);
}
void FilePickerController::beginUpload(bool multiple,bool folder,const QStringList& types) {
    begin({},folder);multiple_=multiple;types_=types;emit rowsChanged();emit changed();
}
bool FilePickerController::allowed(const QString& path) const {
    if(types_.isEmpty())return true;
    const auto name=QFileInfo(path).fileName().toLower();
    const auto mime=QMimeDatabase().mimeTypeForFile(path,QMimeDatabase::MatchExtension);
    for(auto type:types_) {
        type=type.trimmed().toLower();
        if(type=="*/*" || (type.startsWith('.')&&name.endsWith(type)))return true;
        if(type.endsWith("/*")&&mime.name().startsWith(type.left(type.size()-1)))return true;
        if(mime.name()==type||mime.inherits(type))return true;
    }
    return false;
}
void FilePickerController::cancel() {const bool wasOpen=open_;++generation_;++placesGeneration_;open_=false;busy_=false;selectedPaths_.clear();emit changed();if(wasOpen)emit cancelled();}
void FilePickerController::load(const QString& path,int page,const QString& selection) {
    const auto token=++generation_;
    busy_=true;advanceAfterLoad_=false;selectedPath_.clear();current_={};current_.path=path;row_=0;zone_="list";
    emit rowsChanged();emit changed();
    if(!catalog_){busy_=false;current_.error="File browsing is unavailable.";zone_="actions";control_=0;emit changed();return;}
    // History restores the loaded prefix, including selections beyond page one.
    auto pending=std::make_shared<std::function<void(int)>>();
    std::weak_ptr<std::function<void(int)>> weak=pending;
    *pending=[this,token,path,page,selection,weak](int next){
        auto keep=weak.lock();if(!keep)return;
        catalog_->list(path,next,this,[this,token,page,selection,keep](const DirectoryPage& result){
            if(!open_||token!=generation_)return;
            current_.path=result.path;current_.page=result.page;current_.pages=result.pages;current_.error=result.error;
            current_.entries.append(result.entries);
            if(result.error.isEmpty() && result.page<page && result.page+1<result.pages){(*keep)(result.page+1);return;}
            busy_=false;
            for(int i=0;i<current_.entries.size();++i)if(current_.entries[i].path==selection)row_=i;
            zone_=current_.entries.isEmpty()?"actions":"list";control_=canChoose()?1:0;
            emit rowsChanged();emit changed();
        });
    };
    (*pending)(0);
}
void FilePickerController::loadMore() {
    if(!open_||busy_||!hasMore()||!catalog_)return;
    busy_=true;const auto token=generation_;emit changed();
    catalog_->list(current_.path,current_.page+1,this,[this,token](const DirectoryPage& result){
        if(!open_||token!=generation_)return;
        busy_=false;current_.error=result.error;
        if(result.error.isEmpty()) {
            const auto previous=current_.entries.size();current_.entries.append(result.entries);current_.page=result.page;current_.pages=result.pages;
            if(advanceAfterLoad_ && current_.entries.size()>previous)row_=previous;
        }
        advanceAfterLoad_=false;emit rowsChanged();emit changed();
    });
}
void FilePickerController::navigate(const QString& path) {
    if(!open_||path.isEmpty())return;
    if(!current_.path.isEmpty())history_.append({current_.path,current_.page,row_>=0&&row_<current_.entries.size()?current_.entries[row_].path:QString()});
    load(path);
}
void FilePickerController::back() {
    if(history_.isEmpty()){cancel();return;}
    const auto previous=history_.takeLast();load(previous.path,previous.page,previous.selection);
}
void FilePickerController::parentFolder() {const auto parent=QDir::cleanPath(current_.path+"/..");if(parent!=current_.path)navigate(parent);}
void FilePickerController::refresh() {if(open_)load(current_.path);}
void FilePickerController::toggleView() {grid_=!grid_;emit changed();}
void FilePickerController::select(int index) {
    if(busy_||index<0||index>=current_.entries.size())return;
    row_=index;zone_="list";
    selectedPath_=!chooseFolder_&&!current_.entries[index].directory&&allowed(current_.entries[index].path)?current_.entries[index].path:QString();emit changed();
}
void FilePickerController::choose() {
    if(!canChoose())return;
    const auto paths=chooseFolder_?QStringList{current_.path}:multiple_?selectedPaths_:QStringList{selectedPath_};
    for(const auto& path:paths) {
        const QFileInfo file(path);
        if(!file.exists()||!file.isReadable()||(chooseFolder_?!file.isDir():!file.isFile()||!allowed(path))) {current_.error="A selected item is no longer available or has the wrong type. Refresh and select again.";selectedPaths_.clear();emit rowsChanged();emit changed();return;}
    }
    ++generation_;++placesGeneration_;open_=false;busy_=false;selectedPaths_.clear();emit changed();
    emit filesSelected(paths);emit selected(paths.first());
}
void FilePickerController::activate(int index,const QString& zone) {
    if(!open_)return;
    if(zone=="actions") {if(index==0)cancel();else choose();return;}
    if(zone=="toolbar") {if(index==0 && canBack())back();else if(index==1)parentFolder();else if(index==2)refresh();else if(index==3)toggleView();return;}
    if(zone=="places" && index>=0 && index<places_.size()) {place_=index;navigate(places_[index].toMap()["path"].toString());return;}
    if(zone=="crumbs") {const auto items=breadcrumbs();if(index>=0&&index<items.size())navigate(items[index].toMap()["path"].toString());return;}
    if(zone=="list" && !busy_ && index>=0 && index<current_.entries.size()) {
        select(index);const auto entry=current_.entries[index];
        if(entry.directory)navigate(entry.path);
        else if(!chooseFolder_&&allowed(entry.path)){
            if(multiple_){if(!selectedPaths_.removeAll(entry.path))selectedPaths_.append(entry.path);emit rowsChanged();}
            else {zone_="actions";control_=1;}emit changed();
        }
    }
}
void FilePickerController::dispatch(Action action) {
    if(action==Action::Back){back();return;}
    if(action==Action::Confirm){activate(focusIndex(),zone_);return;}
    if(action==Action::ChangeView){toggleView();return;}
    if(action==Action::ScrollUp||action==Action::ScrollDown){emit scrollRequested(action==Action::ScrollDown?1:-1);return;}
    if(zone_=="places") {
        if(action==Action::Up)place_=std::max(0,place_-1);
        if(action==Action::Down)place_=std::min(std::max(0,int(places_.size())-1),place_+1);
        if(action==Action::Right)zone_=current_.entries.isEmpty()?"actions":"list";
    } else if(zone_=="list") {
        const int step=grid_?columns_:1;
        if(action==Action::Left){if(!grid_||row_%step==0)zone_="places";else select(row_-1);}
        if(action==Action::Right){if(grid_ && row_+1<current_.entries.size())select(row_+1);else {zone_="actions";control_=1;}}
        if(action==Action::Up){if(row_<step){zone_="crumbs";control_=std::max(0,int(breadcrumbs().size())-1);}else select(row_-step);}
        if(action==Action::Down) {
            if(row_+step<current_.entries.size())select(row_+step);
            else if(hasMore()){advanceAfterLoad_=true;loadMore();}
            else {zone_="actions";control_=1;}
        }
    } else if(zone_=="crumbs") {
        if(action==Action::Left){if(control_==0){zone_="toolbar";control_=1;}else --control_;}
        if(action==Action::Right)control_=std::min(std::max(0,int(breadcrumbs().size())-1),control_+1);
        if(action==Action::Up){zone_="toolbar";control_=0;}
        if(action==Action::Down)zone_=current_.entries.isEmpty()?"actions":"list";
    } else if(zone_=="toolbar") {
        if(action==Action::Left)control_=std::max(0,control_-1);
        if(action==Action::Right)control_=std::min(3,control_+1);
        if(action==Action::Down){zone_="crumbs";control_=std::max(0,int(breadcrumbs().size())-1);}
    } else {
        if(action==Action::Left)control_=0;
        if(action==Action::Right)control_=1;
        if(action==Action::Up)zone_=current_.entries.isEmpty()?"places":"list";
    }
    emit changed();
}
}
