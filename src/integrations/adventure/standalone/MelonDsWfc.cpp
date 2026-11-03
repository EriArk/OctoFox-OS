#include "platform/emulation/RuntimePaths.h"
// SPDX-License-Identifier: GPL-3.0-or-later
#include "MelonDsWfc.h"
#include "integrations/adventure/CartridgeContent.h"
#include "integrations/adventure/retroarch/RetroArchConfiguration.h"
#include "platform/storage/RuntimeSaveStorage.h"
#include "core/model/GamePlayers.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLockFile>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtEndian>

namespace trainer::dswfc {
namespace {
constexpr int SramLimit=8*1024*1024,WifiBytes=3*(512+256),EnvelopeBytes=9+SramLimit+1+WifiBytes;
QString hash(const QByteArray& b){return QString::fromLatin1(QCryptographicHash::hash(b,QCryptographicHash::Sha256).toHex());}
QString coreName(){
#ifdef Q_OS_WIN
    return "melondsds_libretro.dll";
#else
    return "melondsds_libretro.so";
#endif
}
QJsonObject bundle(const std::atomic_bool& cancel,const std::function<void(const QString&)>& observe) {
    const auto root=bundleRoot();if(observe)observe(root+"/manifest.json");
    QFile file(root+"/manifest.json");if(!file.open(QIODevice::ReadOnly)||file.size()>8192)return {};
    const auto m=QJsonDocument::fromJson(file.readAll()).object();
    if(m["protocol"]!=1||m["source"]!=Source||m["coreSource"]!=CoreSource||m["settings"]!=Settings||m["core"]!=coreName())return {};
    const auto path=root+'/'+coreName(),canonical=QFileInfo(root).canonicalFilePath();if(observe)observe(path);
    if(canonical.isEmpty()||!QFileInfo(path).canonicalFilePath().startsWith(canonical+'/')||m["sha256"].toString().size()!=64||
       retroarch::fileDigest(path,128LL*1024*1024,cancel)!=m["sha256"].toString())return {};
    return m;
}
bool write(const QString& path,const QByteArray& bytes) {
    if(QFileInfo::exists(path)||QFileInfo(path).isSymLink())return false;
    QSaveFile file(path);file.setDirectWriteFallback(false);
    return file.open(QIODevice::WriteOnly)&&file.setPermissions(QFile::ReadOwner|QFile::WriteOwner)&&file.write(bytes)==bytes.size()&&file.commit();
}
QByteArray read(const QString& path,int limit) {
    QFile f(path);if(QFileInfo(path).isSymLink()||!QFileInfo(path).isFile()||!f.open(QIODevice::ReadOnly)||f.size()>limit)return {};
    const auto bytes=f.readAll();return f.error()==QFile::NoError&&bytes.size()==f.size()?bytes:QByteArray{};
}
QString sram(const QString& dir){return dir+"/saves/game.srm";}
QString wifi(const QString& dir){return dir+"/system/melonDS DS/wfcsettings.bin";}
// One fixed-size opaque envelope makes SRAM + WFC identity an atomic return.
// No original standalone save, native firmware or peer data enters this store.
QByteArray pack(const QString& dir) {
    QByteArray out("TOWF1",5);out.resize(EnvelopeBytes);out.fill('\0',EnvelopeBytes);out.replace(0,5,"TOWF1");
    for(const auto& path:{sram(dir),wifi(dir)})if(QFileInfo(path).isSymLink())return {};
    if(QFileInfo::exists(sram(dir))) {
        const auto bytes=read(sram(dir),SramLimit);if(bytes.isEmpty())return {};
        qToLittleEndian<quint32>(bytes.size(),out.data()+5);out.replace(9,bytes.size(),bytes);
    }
    if(QFileInfo::exists(wifi(dir))) {
        const auto bytes=read(wifi(dir),WifiBytes);if(bytes.size()!=WifiBytes)return {};
        out[9+SramLimit]=1;out.replace(10+SramLimit,WifiBytes,bytes);
    }
    return out;
}
bool unpack(const QByteArray& bytes,const QString& dir) {
    if(bytes.size()!=EnvelopeBytes||!bytes.startsWith("TOWF1"))return false;
    const auto size=qFromLittleEndian<quint32>(bytes.constData()+5);
    if(size>SramLimit||bytes.mid(9+size,SramLimit-size)!=QByteArray(SramLimit-size,'\0'))return false;
    const auto flag=bytes[9+SramLimit];if(flag!=0&&flag!=1)return false;
    if(flag==0&&bytes.right(WifiBytes)!=QByteArray(WifiBytes,'\0'))return false;
    return (!size||write(sram(dir),bytes.mid(9,size)))&&(!flag||write(wifi(dir),bytes.right(WifiBytes)));
}
}
QString bundleRoot(){return runtimepaths::data()+"/TrainerOS/emulators/melonds-wfc";}
QJsonObject identity(const AdventureRegistration& r,const RetroArchInstallation& installation,const std::atomic_bool& cancel,
                     const std::function<void(const QString&)>& observe) {
    if(r.adventure.platformId!="nds"||r.adventure.collectionOnly)return {};
    if(observe){observe(r.contentPath);observe(installation.program);observe(installation.runtimeFile);}
    if(!QFileInfo(installation.program).isExecutable()||!QFileInfo(installation.runtimeFile).isExecutable()||bundle(cancel,observe).isEmpty())return {};
    const auto rom=cartridge::read(r.contentPath,"nds",cancel);
    if(rom.bytes.size()<512||(rom.bytes[0x12]!=0&&rom.bytes[0x12]!=2))return {}; // DSi-only is a separate route.
    return {{"id","runtime.melonds.wfc.v1"},{"label",r.adventure.title.left(96)},{"content",rom.digest()},
        {"runtime",hash(QByteArray(Source)+'/'+CoreSource+'/'+Settings)},{"settings",Settings},
        {"players",4},{"lateJoin",false},{"privateProgress",false},{"temporaryProgress",false},{"connections",QJsonArray{"online"}}};
}
ProcessCommand command(const AdventureRegistration& r,const RetroArchInstallation& installation,const QJsonObject& expected,QString owner,QString backupRoot) {
    ProcessCommand cmd;cmd.emulatorRuntime=true;cmd.runtimeControls={{"kind","retroarch"},{"game",r.adventure.id},{"netplay",expected.toVariantMap()},{"temporaryProgress",false}};
    cmd.prepare=[=](ProcessCommand& out,const std::atomic_bool& cancel)->QString {
        if(owner.isEmpty()||owner.size()>128||!QDir::isAbsolutePath(backupRoot)||QFileInfo(backupRoot).isSymLink())return "Your WFC save owner is unavailable.";
        if(!sameMultiplayerGame(identity(r,installation,cancel),expected))return "Your DS game or WFC runtime changed. Choose it again.";
        QString path=backupRoot;
        for(const auto& part:QStringList{"ds-wfc",hash(owner.toUtf8()),expected["content"].toString()}) {
            path+='/'+part;
            if(QFileInfo(path).isSymLink()||!QDir().mkpath(path)||!QFile::setPermissions(path,QFile::ReadOwner|QFile::WriteOwner|QFile::ExeOwner))return "Couldn't protect your WFC progress.";
        }
        auto lock=std::make_shared<QLockFile>(path+"/session.lock");lock->setStaleLockTime(0);
        if(!lock->tryLock())return "This WFC progress is already in use.";
        const SaveTargetResolver resolve=[=](const AdventureRegistration& current) {
            SaveTarget t;t.adventureId=current.adventure.id;t.title=current.adventure.title;t.savePath=path+"/progress.bin";
            t.contentRevision=cartridge::read(current.contentPath,"nds",std::atomic_bool{false}).digest();
            t.contextRevision=QString(Settings)+'/'+owner+'/'+QString::number(current.revision);
            t.backupOwner=owner;t.lineageOwner=owner;t.supported=!t.contentRevision.isEmpty();return t;
        };
        const auto seed=captureRuntimeSave(backupRoot,r,resolve);if(!seed.error.isEmpty())return seed.error;
        auto stage=std::make_shared<QTemporaryDir>(path+"/session-XXXXXX");
        if(!stage->isValid()||!retroarch::safePath(stage->path()))return "Couldn't prepare the WFC session.";
        const auto dir=stage->path();
        for(const auto& folder:{"saves","states","system/melonDS DS"})if(!QDir().mkpath(dir+'/'+folder))return "Couldn't prepare WFC storage.";
        if(seed.existed&&!unpack(seed.bytes,dir))return "Your WFC progress is damaged. Its original copy was kept.";
        const auto rom=cartridge::read(r.contentPath,"nds",cancel);
        if(rom.digest()!=expected["content"].toString()||!write(dir+"/game.nds",rom.bytes))return "The DS cartridge changed during preparation.";
        auto address=QCryptographicHash::hash(("traineros-ds-wfc/"+owner+'/'+expected["content"].toString()).toUtf8(),QCryptographicHash::Sha256).left(6);
        address[0]=char(static_cast<unsigned char>(address[0])&0xfc);
        const auto mac=address.toHex(':');
        const QByteArray options="melonds_console_mode = \"ds\"\nmelonds_sysfile_mode = \"builtin\"\nmelonds_boot_mode = \"direct\"\n"
            "melonds_network_mode = \"indirect\"\nmelonds_firmware_wfc_dns = \"178.62.43.212\"\n"
            "melonds_render_mode = \"software\"\nmelonds_jit_enable = \"enabled\"\nmelonds_firmware_username = \"melonDS DS\"\n"
            "melonds_homebrew_sdcard = \"disabled\"\n"
            "melonds_mac_address_mode = \""+mac+"\"\n";
        if(!write(dir+"/core.opt",options)||!write(dir+"/system/melonDS DS/console.txt",mac+'\n'))return "Couldn't prepare the WFC console settings.";
        QByteArray config="config_save_on_exit = \"false\"\nglobal_core_options = \"true\"\nauto_overrides_enable = \"false\"\n"
            "auto_remaps_enable = \"false\"\ngame_specific_options = \"false\"\nrun_ahead_enabled = \"false\"\nrewind_enable = \"false\"\n"
            "preemptive_frames_enable = \"false\"\ncheevos_enable = \"false\"\ncheat_apply_after_load = \"false\"\n"
            "savestate_auto_save = \"false\"\nsavestate_auto_load = \"false\"\nautosave_interval = \"0\"\n"
            "savefiles_in_content_dir = \"false\"\nsort_savefiles_enable = \"false\"\nsort_savefiles_by_content_enable = \"false\"\n"
            "history_list_enable = \"false\"\nnetplay_start_as_server = \"false\"\nnetplay_start_as_client = \"false\"\n"
            "netplay_start_as_spectator = \"false\"\nnetplay_nat_traversal = \"false\"\nnetplay_public_announce = \"false\"\n"
            "pause_nonactive = \"false\"\nquit_press_twice = \"false\"\nstdin_cmd_enable = \"true\"\n";
        for(const auto& pair:QList<QPair<QString,QString>>{{"system_directory",dir+"/system"},{"savefile_directory",dir+"/saves"},{"savestate_directory",dir+"/states"},{"core_options_path",dir+"/core.opt"}})
            config+=pair.first.toUtf8()+" = \""+pair.second.toUtf8()+"\"\n";
        if(!write(dir+"/session.cfg",config))return "Couldn't prepare WFC launch settings.";
        out.program=installation.program;out.arguments=installation.prefixArguments;
        if(!installation.configFile.isEmpty())out.arguments<<"--config"<<installation.configFile;
        out.arguments<<"--appendconfig"<<dir+"/session.cfg"<<"--fullscreen"<<"-L"<<bundleRoot()+'/'+coreName()<<dir+"/game.nds";
        out.workingDirectory=dir;
        out.finalize=[=](const ProcessOutcome& outcome)->QString {
            if(!outcome.started)return {};
            stage->setAutoRemove(false);
            if(outcome.crashed||outcome.stopped||outcome.exitCode!=0)return "WFC ended unexpectedly. Its progress copy was kept for recovery.";
            const auto bytes=pack(dir);if(bytes.isEmpty())return "WFC progress could not be verified. Its session copy was kept.";
            if(seed.existed&&((qFromLittleEndian<quint32>(seed.bytes.constData()+5)&&!qFromLittleEndian<quint32>(bytes.constData()+5))||
                (seed.bytes[9+SramLimit]&&!bytes[9+SramLimit])))return "WFC progress is missing. Its prior copy and session were kept.";
            const auto error=returnRuntimeSave(backupRoot,r,seed,bytes,resolve);
            if(error.isEmpty())stage->setAutoRemove(true);
            return error;
        };
        out.settled=[lock](const ProcessOutcome&){lock->unlock();};
        return {};
    };return cmd;
}
}
