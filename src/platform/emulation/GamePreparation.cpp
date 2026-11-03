#include "RuntimePaths.h"
#include "GamePreparation.h"
#include "integrations/adventure/retroarch/RetroArchConfiguration.h"
#include "integrations/adventure/retroarch/RetroArchAdapter.h"
#include "integrations/adventure/standalone/NintendoOnline.h"
#include "platform/files/ArchiveExtractor.h"
#include "core/repository/RomPlatforms.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QLockFile>
#include <QTemporaryFile>
#include <QSettings>
#include <QDateTime>
#include <QSaveFile>
#include <QTemporaryDir>
#include <QDirIterator>

static void preparationResources(){Q_INIT_RESOURCE(game_preparation);}

namespace trainer::gamePreparation {
namespace {
constexpr qint64 Limit=64LL*1024*1024;
QByteArray read(const QString& path) { QFile f(path);return f.open(QIODevice::ReadOnly)&&f.size()<4*1024*1024?f.readAll():QByteArray{}; }
QString digest(QFile& f, QCryptographicHash::Algorithm algorithm, const std::atomic_bool& cancel) {
    QCryptographicHash hash(algorithm);while(!f.atEnd()&&!cancel){const auto chunk=f.read(256*1024);if(chunk.isEmpty()&&f.error()!=QFile::NoError)return {};hash.addData(chunk);}
    return cancel||f.error()!=QFile::NoError?QString():QString::fromLatin1(hash.result().toHex());
}
QString validation(const File& file, const QString& path, const std::atomic_bool& cancel) {
    QFile f(path);const QFileInfo info(path);
    if(!info.isFile()||info.size()<=0||info.size()>Limit||!f.open(QIODevice::ReadOnly))return "File is missing, empty, too large or unreadable.";
    if(file.size>0&&info.size()!=file.size)return QString("Expected %1 bytes; this file has %2.").arg(file.size).arg(info.size());
    if(!file.md5.isEmpty()&&digest(f,QCryptographicHash::Md5,cancel)!=file.md5)return "This file does not match the expected BIOS checksum.";
    return cancel?QString("Cancelled."):QString();
}
bool parentsSafe(const QString& root,const QString& name) {
    if(!QDir::isAbsolutePath(root)||!safeRelativeName(name))return false;
    auto path=QDir::cleanPath(root);if(QFileInfo(path).isSymLink())return false;
    for(const auto& part:name.split('/')) {path+='/'+part;const QFileInfo f(path);if(f.isSymLink()||(f.exists()&&f.canonicalFilePath().isEmpty()))return false;}
    return true;
}
}
bool safeRelativeName(const QString& name) {
    if(name.isEmpty()||QDir::isAbsolutePath(name)||name.contains('\\')||name.contains(':'))return false;
    for(const auto c:name)if(c.unicode()<32)return false;
    for(const auto& part:name.split('/'))if(part.isEmpty()||part=="."||part=="..")return false;
    return true;
}
Inventory inventory(const QHash<QString,QJsonObject>& profiles,const QString& stateDirectory) {
    preparationResources();
    Inventory out;
    const auto note=[&](QString group,QString title,QString detail,QString state){out.notes<<QVariantMap{{"id",group+':'+title},{"group",group},{"title",title},{"detail",detail},{"state",state},{"importable",false}};};
    const auto ra=profiles.value("retroarch");
    if(!ra.isEmpty()) {
        const auto settings=retroarch::readSettings(ra["configFile"].toString());
        const auto root=retroarch::configuredPath(settings,"system_directory");
        const auto catalogue=QJsonDocument::fromJson(read(":/preparation/firmware.json")).object();
        const QDir cores(ra["coresDirectory"].toString());
        // One bounded directory listing, never a ROM scan. Cover installed cores, not a game whitelist.
        for(const auto& path:cores.entryList({"*_libretro.so","*_libretro.dll","*_libretro.dylib"},QDir::Files)) {
            const auto core=path.left(path.indexOf("_libretro."));
            const auto info=catalogue[core].toObject();
            QStringList platforms;for(const auto& route:romPlatforms())if(route.core==core)platforms<<route.id;
            if(core=="melondsds")platforms={"nds"};
            if(core=="sameboy"||core=="DoubleCherryGB")platforms={"gb","gbc"};
            if(core=="gpsp"||core=="mgba_splitscreen")platforms={"gba"};
            if(platforms.isEmpty())platforms<<"core:"+(info["title"].toString().isEmpty()?core:info["title"].toString());
            for(const auto& group:platforms) {
            if(info.isEmpty()){note(group,"Firmware requirements","Requirements for this emulator have not been described yet.","Not described");continue;}
            const auto files=info["files"].toArray();
            bool listed=false;
            for(const auto& v:files){const auto f=v.toObject();const auto name=f["path"].toString();if(!safeRelativeName(name))continue;
                // Requirements belong to the selected platform, not every machine a core can emulate.
                if(core=="genesis_plus_gx") {
                    if(group=="segacd"&&!name.startsWith("bios_CD_"))continue;
                    if(group=="megadrive"&&(name.startsWith("bios_CD_")||name.endsWith(".sms")||name=="bios.gg"))continue;
                    if(group=="mastersystem"&&!name.endsWith(".sms"))continue;
                    if(group=="gamegear"&&name!="bios.gg")continue;
                    if(group=="sg1000")continue;
                }
                if(core=="picodrive"&&(group=="pico"||group=="sega32x"))continue;
                if(core=="mednafen_pce_fast"&&group=="pcengine")continue;
                if((core=="mgba"||core=="gpsp")&&group=="gba"&&name!="gba_bios.bin")continue;
                if(core=="gambatte"&&((group=="gb"&&name!="gb_bios.bin")||(group=="gbc"&&name!="gbc_bios.bin")))continue;
                if(core=="fbneo"&&group=="neogeo"&&name!="fbneo/neogeo.zip"&&name!="fbneo/hiscore.dat")continue;
                listed=true;
                out.files<<File{core+':'+group+':'+name,group,f["title"].toString(),root,name,f["md5"].toString(),
                    "Used by ordinary play and compatible RetroArch multiplayer. Optional files may be needed by particular games or regions.",-1,f["optional"].toBool(),f["directory"].toBool()};}
            if(!listed)note(group,"BIOS / firmware","No external BIOS is required for this platform.","No files listed");
            const auto runtime=ra["program"].toString();if(!QFileInfo(runtime).isFile())note(group,"Emulator","Install or repair the emulator.","Missing runtime");
            }
        }
        if(!QDir::isAbsolutePath(root))note("RetroArch","BIOS folder","The selected emulator has no absolute system_directory. Configure the runtime before importing files.","Needs setup");
    }
    for(auto i=profiles.cbegin();i!=profiles.cend();++i) {
        if(i.key()=="retroarch")continue;
        const auto p=i.value();const auto runtime=p["runtimeFile"].toString().isEmpty()?p["program"].toString():p["runtimeFile"].toString();
        for(const auto& value:p["validatedPlatforms"].toArray()) {
            const auto group=value.toString();if(group.isEmpty())continue;
            if(!QFileInfo(runtime).isFile())note(group,"Emulator","Install or repair the emulator.","Missing runtime");
            else if(group=="psp"||group=="gc")note(group,"BIOS / firmware","No external BIOS is required for ordinary play.","No files listed");
            else if(group!="n3ds"&&group!="wii"&&group!="wiiu")note(group,"Firmware requirements","The native firmware installer has not been integrated yet.","Not described");
        }
    }
    for(const auto& platform:{QString("wii"),QString("n3ds"),QString("wiiu")}) {
        const auto adapter=platform=="wii"?"dolphin":platform=="n3ds"?"azahar":"cemu";if(!profiles.contains(adapter))continue;
        auto setup=nintendoOnline::setup(platform,stateDirectory);
        const auto group=platform;
        if(setup.installation.runtimeFile.isEmpty()) {
            note(group,"Emulator","Install or repair the native emulator before importing its console files.","Missing runtime");
            note(group,"Online","Online setup is waiting for a valid emulator configuration.","Online setup");
            continue;
        }
        for(auto file:nintendoOnline::requiredFiles(setup)){file.group=group;out.files<<file;}
        if(setup.service=="off")setup.service=platform=="wii"?"wiimmfi":"pretendo";
        const auto error=nintendoOnline::check(setup);
        note(group,"Online",error.isEmpty()?"Files are prepared. Service sign-in has not been verified in this session.":error,"Online setup");
    }
    if(profiles.isEmpty())note("Games","Emulators","No configured emulators were found. Install a supported runtime; this screen will use its actual firmware locations.","Needs setup");
    return out;
}
QVariantMap inspect(const File& f,const std::atomic_bool& cancel) {
    const bool safe=parentsSafe(f.root,f.name);
    const auto path=QDir(f.root).filePath(f.name);const auto issue=!safe?QString("The destination is unavailable or uses a symbolic link. Existing files were kept."):
        f.directory?(QDir(path).exists()&&!QDir(path).entryList(QDir::Files|QDir::Dirs|QDir::NoDotAndDotDot).isEmpty()?QString():QString("Choose the complete, already extracted folder. Firmware archives need their native installer first.")):validation(f,path,cancel);
    const bool exists=QFileInfo::exists(path)||QFileInfo(path).isSymLink();
    return {{"id",f.id},{"group",f.group},{"title",f.title},{"filename",f.name},{"name",QFileInfo(f.name).fileName()},{"destination",path},
        {"detail",f.detail},{"requirement",f.optional?"Optional / game-dependent":"Required for this mode"},
        {"state",issue.isEmpty()?(f.md5.isEmpty()?(f.size>0?"Found · size checked":"Found · contents unverified"):"Checksum checked"):exists?"Needs attention":f.optional?"Optional · absent":"Missing"},
        {"problem",issue},{"importable",safe&&(!exists||(f.directory&&QFileInfo(path).isDir()))},{"directory",f.directory},{"size",f.size},{"optional",f.optional},{"present",exists},{"checked",issue.isEmpty()}};
}
QString importFile(const File& f,const QString& source,const std::atomic_bool& cancel,const std::function<void(qint64,qint64)>& progress) {
    if(!parentsSafe(f.root,f.name))return "The destination changed or is unsafe. Refresh preparation.";
    if(f.directory) {
        if(!QFileInfo(source).isDir()||QFileInfo(source).isSymLink())return "Choose an extracted firmware folder.";
        const auto target=QDir(f.root).filePath(f.name);
        const bool merge=QFileInfo(target).isDir();
        if((QFileInfo::exists(target)&&!merge)||QFileInfo(target).isSymLink())return "The destination already exists and was kept unchanged.";
        struct Entry {QString path,relative;qint64 size;};QList<Entry> entries;qint64 total=0;
        QDirIterator it(source,QDir::AllEntries|QDir::Hidden|QDir::System|QDir::NoDotAndDotDot,QDirIterator::Subdirectories);
        while(it.hasNext()) {if(cancel)return "Cancelled. No firmware was installed.";it.next();const auto info=it.fileInfo();
            if(info.isSymLink())return "The chosen folder contains symbolic links. Choose regular local firmware files.";
            if(info.isDir())continue;
            const auto name=QDir(source).relativeFilePath(info.absoluteFilePath());
            if(!info.isFile()||!safeRelativeName(name)||info.size()<=0||info.size()>Limit||entries.size()>=4096||(total+=info.size())>512LL*1024*1024)return "This folder is not a bounded firmware set. Choose only its system resource folder.";
            entries<<Entry{info.absoluteFilePath(),name,info.size()};
        }
        if(entries.isEmpty())return "The selected folder contains no firmware files.";
        if(!QDir().mkpath(QFileInfo(target).absolutePath()))return "Could not create the destination parent folder.";
        const auto canonicalRoot=QFileInfo(f.root).canonicalFilePath();
        QLockFile lock(QDir(f.root).filePath(".traineros-firmware.lock"));lock.setStaleLockTime(0);if(!lock.tryLock())return "Another firmware import is using this folder.";
        QTemporaryDir stage(QFileInfo(target).absolutePath()+"/.traineros-firmware-XXXXXX");if(!stage.isValid())return "Could not stage the firmware folder.";
        qint64 done=0;
        for(const auto& entry:entries){File part{entry.relative,f.group,entry.relative,stage.path(),entry.relative,{}, {},entry.size,false};
            const auto error=importFile(part,entry.path,cancel,[&](qint64 n,qint64){if(progress)progress(done+n,total);});if(!error.isEmpty())return error;done+=entry.size;}
        if(cancel)return "Cancelled. No firmware was installed.";
        if(merge) {
            // Verify all conflicts first; merge only absent files. Never replace a native BIOS or preference.
            for(const auto& entry:entries) {
                const auto destination=target+'/'+entry.relative;
                if(!parentsSafe(target,entry.relative))return "The firmware destination contains a symbolic link.";
                if(QFileInfo::exists(destination)) {
                    QFile old(destination),next(stage.path()+'/'+entry.relative);
                    if(!old.open(QIODevice::ReadOnly)||!next.open(QIODevice::ReadOnly)||old.size()!=entry.size||digest(old,QCryptographicHash::Sha256,cancel)!=digest(next,QCryptographicHash::Sha256,cancel))
                        return "A different firmware file already exists. It and your selected folder were kept.";
                }
            }
            if(cancel)return "Cancelled. No firmware was installed.";
            if(QFileInfo(f.root).canonicalFilePath()!=canonicalRoot)return "The destination changed. Original data was kept.";
            for(const auto& entry:entries)if(!QFileInfo::exists(target+'/'+entry.relative)) {
                File part{entry.relative,f.group,entry.relative,target,entry.relative,{},{},entry.size,false};
                const auto error=importFile(part,stage.path()+'/'+entry.relative,cancel);
                if(!error.isEmpty())return error+" Completed imports and original data were kept.";
            }
            return {};
        }
        if(!parentsSafe(f.root,f.name)||QFileInfo(f.root).canonicalFilePath()!=canonicalRoot||QFileInfo::exists(target)||!QDir().rename(stage.path(),target))return "Could not publish the firmware folder. Existing data was kept.";
        stage.setAutoRemove(false);return {};
    }
    if(f.md5.isEmpty()&&f.size<0&&QFileInfo(source).fileName().compare(QFileInfo(f.name).fileName(),Qt::CaseInsensitive)!=0)
        return "This requirement has no reference checksum. Choose the exact named file shown on the preparation screen.";
    const auto issue=validation(f,source,cancel);if(!issue.isEmpty())return issue;
    const QFileInfo original(source);QFile input(source);
    if(!input.open(QIODevice::ReadOnly))return "Could not open the selected file.";
    if(!QDir().mkpath(f.root))return "Could not create the emulator firmware folder.";
    const auto canonicalRoot=QFileInfo(f.root).canonicalFilePath();
    QLockFile lock(QDir(f.root).filePath(".traineros-firmware.lock"));lock.setStaleLockTime(0);
    if(!lock.tryLock())return "Another firmware import is using this folder. Try again after it finishes.";
    const auto destination=QDir(f.root).filePath(f.name);
    if(QFileInfo::exists(destination)||QFileInfo(destination).isSymLink())return "A file already exists here. It was kept unchanged; refresh to check it.";
    if(!parentsSafe(f.root,f.name)||!QDir().mkpath(QFileInfo(destination).absolutePath()))return "Could not prepare the destination folder.";
    QTemporaryFile staged(QFileInfo(destination).absolutePath()+"/.traineros-firmware-XXXXXX");
    if(!staged.open())return "Could not create the temporary file. Check free space and permissions.";
    staged.setPermissions(QFile::ReadOwner|QFile::WriteOwner);
    qint64 copied=0;while(!input.atEnd()) {
        if(cancel)return "Cancelled. No firmware was installed.";
        const auto bytes=input.read(256*1024);if(bytes.isEmpty()&&input.error()!=QFile::NoError)return "Reading the selected file failed.";
        if(staged.write(bytes)!=bytes.size())return "Copy failed. Check free space or reconnect storage.";
        copied+=bytes.size();if(copied>Limit)return "The selected file changed during copying.";if(progress)progress(copied,original.size());
    }
    if(!staged.flush())return "Could not finish writing the firmware.";
    const auto after=QFileInfo(source);
    if(copied!=original.size()||after.size()!=original.size()||after.lastModified()!=original.lastModified())return "The selected file changed. Choose it again.";
    const auto stagedIssue=validation(f,staged.fileName(),cancel);if(!stagedIssue.isEmpty())return stagedIssue;
    input.seek(0);staged.seek(0);
    if(digest(input,QCryptographicHash::Sha256,cancel)!=digest(staged,QCryptographicHash::Sha256,cancel))return "The copied file did not match its source.";
    if(cancel)return "Cancelled. No firmware was installed.";
    if(!parentsSafe(f.root,f.name)||QFileInfo(f.root).canonicalFilePath()!=canonicalRoot)return "The destination changed during copying. Nothing was installed.";
    staged.close(); // QFile::rename never replaces an existing file, including a late conflict.
    if(!staged.rename(destination))return "Could not publish the file. An existing destination was kept unchanged.";
    staged.setAutoRemove(false);return {};
}
QString registerDiscFirmware(const QString& directory,const std::atomic_bool& cancel) {
    auto path=runtimepaths::profileDirectory(directory)+"/retroarch.json";if(!QFileInfo::exists(path))path=runtimepaths::profileDirectory(directory)+"/discovered/retroarch.json";
    const auto original=read(path);auto profile=QJsonDocument::fromJson(original).object();if(profile["version"]!=1)return {};
    const auto root=retroarch::configuredPath(retroarch::readSettings(profile["configFile"].toString()),"system_directory");
    if(!QDir::isAbsolutePath(root))return {};
    QJsonObject hashes;
    for(const auto* name:{"bios_CD_U.bin","bios_CD_E.bin","bios_CD_J.bin"}) {
        if(!parentsSafe(root,name)||QFileInfo(root+'/'+name).size()!=131072)return {};
        QFile f(root+'/'+name);if(!f.open(QIODevice::ReadOnly))return {};const auto hash=digest(f,QCryptographicHash::Sha256,cancel);if(hash.isEmpty())return {};hashes[name]=hash;
    }
    auto firmware=profile["discFirmware"].toObject();
    if(firmware.value("segacd").toObject()==hashes)return {};
    if(firmware.contains("segacd"))return "Files copied, but the saved Sega CD firmware fingerprints differ. The existing runtime profile was kept.";
    QLockFile lock(path+".preparation.lock");lock.setStaleLockTime(0);if(!lock.tryLock())return "Files copied; runtime profile is busy. Check again after its operation finishes.";
    if(cancel)return "Firmware registration cancelled; imported files were kept.";
    if(read(path)!=original||QFileInfo(path).isSymLink())return "Runtime profile changed. Imported files were kept; check setup again.";
    const auto backup=path+".before-firmware-import";
    if(QFileInfo::exists(backup)&&read(backup)!=original)return "An earlier firmware profile backup exists. Existing files and profile were kept.";
    if(!QFileInfo::exists(backup)&&!QFile::copy(path,backup))return "Could not back up the runtime profile. Imported files were kept.";
    firmware["segacd"]=hashes;profile["discFirmware"]=firmware;
    QSaveFile output(path);output.setDirectWriteFallback(false);const auto bytes=QJsonDocument(profile).toJson();
    if(!output.open(QIODevice::WriteOnly)||output.write(bytes)!=bytes.size()||cancel||read(path)!=original||!output.commit())return "Could not register the copied firmware. The previous runtime profile and backup were kept.";
    return {};
}
QString PackResult::summary() const {
    auto text=QString("%1 installed · %2 already present · %3 unused pack files.").arg(installed).arg(present).arg(unmatched);
    if(archiveRemoved)text+=" Source archive moved to Trash.";
    else text+=" Source archive kept.";
    if(!problems.isEmpty())text+='\n'+problems.join('\n');
    return text;
}
PackResult importPack(const Inventory& inventory,const QString& source,const std::atomic_bool& cancel,
                      const std::function<void(qint64,qint64)>& progress,bool removeArchive,const std::function<QString()>& finalize) {
    PackResult result;
    const QFileInfo original(source);
    if(!original.isFile()||original.isSymLink()||original.size()>2LL*1024*1024*1024){result.problems<<"Choose a local BIOS pack archive up to 2 GiB.";return result;}
    QFile archive(source);if(!archive.open(QIODevice::ReadOnly)){result.problems<<"Could not read the archive.";return result;}
    const auto archiveHash=digest(archive,QCryptographicHash::Sha256,cancel);archive.close();
    if(cancel||archiveHash.isEmpty()){result.problems<<"Pack import cancelled.";return result;}
    QTemporaryDir extracted(QDir::tempPath()+"/traineros-firmware-pack-XXXXXX");
    if(!extracted.isValid()){result.problems<<"Could not prepare a temporary folder.";return result;}
    const auto error=ArchiveExtractor::extract(source,extracted.path(),[&]{return cancel.load();},[&](double n){if(progress)progress(qint64(n*40),100);},2LL*1024*1024*1024);
    if(!error.isEmpty()){result.problems<<error;return result;}
    QStringList paths,folders;QDirIterator it(extracted.path(),QDir::AllEntries|QDir::NoDotAndDotDot|QDir::Hidden,QDirIterator::Subdirectories);
    while(it.hasNext()){it.next();if(it.fileInfo().isFile())paths<<it.filePath();else if(it.fileInfo().isDir())folders<<it.filePath();}
    QHash<QString,QString> md5,sha;QSet<QString> used,targets;
    const auto hash=[&](const QString& path,QCryptographicHash::Algorithm type)->QString {
        auto& cache=type==QCryptographicHash::Md5?md5:sha;if(cache.contains(path))return cache[path];
        QFile f(path);if(!f.open(QIODevice::ReadOnly)||f.size()>Limit)return {};const auto value=digest(f,type,cancel);cache[path]=value;return value;
    };
    int step=0;
    for(const auto& requirement:inventory.files) {
        if(cancel){result.problems<<"Pack import cancelled. Already installed files were kept.";break;}
        if(progress)progress(40+qint64(55)*++step/std::max<qsizetype>(1,inventory.files.size()),100);
        QStringList candidates;bool namedButInvalid=false;
        for(const auto& path:requirement.directory?folders:paths) {
            if(cancel)break;
            const auto relative=QDir(extracted.path()).relativeFilePath(path);
            const bool named=QFileInfo(path).fileName().compare(QFileInfo(requirement.name).fileName(),Qt::CaseInsensitive)==0;
            if(requirement.directory){if(relative.compare(requirement.name,Qt::CaseInsensitive)==0||relative.endsWith('/'+requirement.name,Qt::CaseInsensitive))candidates<<path;continue;}
            // Known BIOS can be recognized by digest even after pack authors rename it.
            const bool sizeOk=requirement.size<0||QFileInfo(path).size()==requirement.size;
            if(!requirement.md5.isEmpty()) {
                if(sizeOk&&hash(path,QCryptographicHash::Md5)==requirement.md5)candidates<<path;
                else if(named)namedButInvalid=true;
            } else if(named&&sizeOk)candidates<<path;
            else if(named)namedButInvalid=true;
        }
        if(candidates.isEmpty()){if(namedButInvalid)result.problems<<requirement.name+": pack file has the wrong size/checksum.";continue;}
        const auto candidate=candidates.first();
        bool ambiguous=requirement.directory&&candidates.size()>1;
        if(!requirement.directory)for(const auto& p:candidates)if(hash(p,QCryptographicHash::Sha256)!=hash(candidate,QCryptographicHash::Sha256))ambiguous=true;
        if(ambiguous){result.problems<<requirement.name+": several different matching files; choose this component individually.";continue;}
        for(const auto& p:candidates) {if(requirement.directory){for(const auto& file:paths)if(file.startsWith(p+'/'))used.insert(file);}else used.insert(p);}
        const auto target=QDir::cleanPath(QDir(requirement.root).absoluteFilePath(requirement.name));
        if(targets.contains(target))continue;targets.insert(target);
        if(QFileInfo::exists(target)||QFileInfo(target).isSymLink()) {
            bool identical=!requirement.directory&&!QFileInfo(target).isSymLink()&&!hash(target,QCryptographicHash::Sha256).isEmpty()&&hash(target,QCryptographicHash::Sha256)==hash(candidate,QCryptographicHash::Sha256);
            if(requirement.directory&&parentsSafe(requirement.root,requirement.name)&&QFileInfo(target).isDir()) {
                identical=true;
                for(const auto& p:paths)if(p.startsWith(candidate+'/')){const auto dst=target+'/'+QDir(candidate).relativeFilePath(p);if(!parentsSafe(target,QDir(candidate).relativeFilePath(p))||hash(dst,QCryptographicHash::Sha256).isEmpty()||hash(dst,QCryptographicHash::Sha256)!=hash(p,QCryptographicHash::Sha256)){identical=false;break;}}
            }
            if(identical)++result.present;
            else if(requirement.directory){const auto error=importFile(requirement,candidate,cancel);if(error.isEmpty())++result.installed;else result.problems<<requirement.name+": "+error;}
            else result.problems<<requirement.name+": existing data differs and was kept. Archive retained.";
            continue;
        }
        const auto installed=importFile(requirement,candidate,cancel);
        if(installed.isEmpty())++result.installed;else result.problems<<requirement.name+": "+installed;
    }
    result.unmatched=paths.size()-used.size();result.problems.removeDuplicates();
    if(!result.installed&&!result.present&&result.problems.isEmpty())result.problems<<"No matching requirements for the installed emulators were found. Archive kept.";
    if(cancel&&result.problems.isEmpty())result.problems<<"Cancelled. Source archive kept.";
    if(finalize&&result.problems.isEmpty()&&(result.installed||result.present)) {const auto error=finalize();if(!error.isEmpty())result.problems<<error;}
    if(removeArchive&&result.problems.isEmpty()&&(result.installed||result.present)) {
        const auto sourcePath=original.canonicalFilePath();
        for(const auto& file:inventory.files){const auto target=QFileInfo(QDir(file.root).filePath(file.name)).canonicalFilePath();if(!target.isEmpty()&&(target==sourcePath||(file.directory&&sourcePath.startsWith(target+'/')))){
            result.problems<<"The selected archive is inside an active firmware requirement. It was kept.";return result;}}
        QFile current(source);
        if(QFileInfo(source).size()!=original.size()||QFileInfo(source).lastModified()!=original.lastModified()||!current.open(QIODevice::ReadOnly)||digest(current,QCryptographicHash::Sha256,cancel)!=archiveHash)
            result.problems<<"The source archive changed. It was kept.";
        else {
            current.close();
            if(!cancel&&QFile::moveToTrash(source))result.archiveRemoved=true;
            else result.problems<<"Import completed, but the archive could not be moved to Trash. It was kept.";
        }
    }
    if(progress)progress(100,100);return result;
}
}
