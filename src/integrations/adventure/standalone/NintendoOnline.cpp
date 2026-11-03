#include "platform/emulation/RuntimePaths.h"
// SPDX-License-Identifier: GPL-3.0-or-later
#include "NintendoOnline.h"
#include "DolphinNetplay.h"
#include "AzaharNetplay.h"
#include "integrations/adventure/retroarch/RetroArchConfiguration.h"
#include "core/model/GamePlayers.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QLockFile>
#include <QSettings>
#include <QStandardPaths>
#include <QXmlStreamReader>

namespace trainer::nintendoOnline {
namespace {
QString adapter(const QString& platform) { return platform=="wii"?"dolphin":platform=="n3ds"?"azahar":platform=="wiiu"?"cemu":QString(); }
QByteArray read(const QString& path, qint64 limit=1024*1024) {
    QFile f(path); if(!f.open(QIODevice::ReadOnly)||f.size()>limit)return {};
    const auto bytes=f.readAll();return f.error()==QFile::NoError?bytes:QByteArray{};
}
struct CemuAccount { QString mlc, id; bool pretendo=false; };
CemuAccount cemuAccount(const Setup& s) {
    QXmlStreamReader xml(read(s.config+"/settings.xml")); CemuAccount result;
    QMap<QString,QString> selected;
    QStringList elements;
    while(!xml.atEnd()) {
        xml.readNext();
        if(xml.isEndElement()){if(!elements.isEmpty())elements.removeLast();continue;}
        if(!xml.isStartElement())continue;
        const auto name=xml.name().toString(),parent=elements.value(elements.size()-1);
        if(name=="mlc_path"|| (name=="PersistentId"&&parent=="Account")) {
            const auto text=xml.readElementText();
            if(name=="mlc_path")result.mlc=text;else result.id=text;
        } else {
            if(name=="SelectedService"&&parent=="AccountService")
                selected.insert(xml.attributes().value("PersistentId").toString(),xml.attributes().value("Service").toString());
            elements.append(name);
        }
    }
    bool ok=false;const auto pid=result.id.toUInt(&ok,10);
    if(xml.hasError()||!ok||pid<0x80000001)return {};
    result.pretendo=selected.value(result.id)=="2";
    result.id=QString::number(pid,16).rightJustified(8,'0');
    if(result.mlc.isEmpty())result.mlc=s.data+"/mlc01";
    return result;
}
}
QStringList services(const QString& platform) {
    if(platform=="wii")return {"off","wiimmfi","wiilink"};
    if(platform=="n3ds"||platform=="wiiu")return {"off","pretendo"};
    return {};
}
QString guide(const QString& platform,const QString& service) {
    if(platform=="wii")return service=="wiilink"?"https://wfc.wiilink.ca/dolphin":"https://wiimmfi.de/patcher/";
    return platform=="n3ds"?"https://pretendo.network/docs/install/azahar":"https://pretendo.network/docs/install/cemu";
}
bool mode(const QString& id) {
    return id=="runtime.nintendo.wii.wiimmfi.v1"||id=="runtime.nintendo.wii.wiilink.v1"||
        id=="runtime.nintendo.n3ds.pretendo.v1"||id=="runtime.nintendo.wiiu.pretendo.v1";
}
Setup setup(const QString& platform,const QString& stateDirectory) {
    Setup s;s.platform=platform;const auto a=adapter(platform);if(a.isEmpty())return s;
    QSettings preferences;s.service=preferences.value("nintendo-online/"+platform+"/service","off").toString();
    s.prepared=preferences.value("nintendo-online/"+platform+"/prepared/"+s.service,false).toBool();
    auto path=runtimepaths::profileDirectory(stateDirectory)+"/"+a+".json";
    if(!QFileInfo::exists(path))path=runtimepaths::profileDirectory(stateDirectory)+"/discovered/"+a+".json";
    const auto object=QJsonDocument::fromJson(read(path,65536)).object();
    s.installation=StandaloneInstallation::fromJson(object,a);
    const auto name=platform=="wii"?QString("dolphin-emu"):platform=="n3ds"?QString("azahar-emu"):QString("Cemu");
    s.config=runtimepaths::config()+'/'+name;
    s.data=runtimepaths::data()+'/'+name;
    const auto app=platform=="wii"?QString("org.DolphinEmu.dolphin-emu"):platform=="n3ds"?QString("org.azahar_emu.Azahar"):QString("info.cemu.Cemu");
    if(s.installation.prefixArguments.contains(app)) {
        const auto base=runtimepaths::userHome()+"/.var/app/"+app;
        s.config=base+"/config/"+name;s.data=base+"/data/"+name;
    }
    // Upstream portable layouts take precedence over XDG directories.
    const auto executable=QFileInfo(s.installation.runtimeFile).absolutePath();
    if(platform=="wiiu"&&QFileInfo(executable+"/portable").isDir())s.config=s.data=executable+"/portable";
    if(platform=="n3ds"&&QFileInfo(executable+"/user").isDir()){s.data=executable+"/user";s.config=s.data+"/config";}
    if(platform=="wii"&&QFileInfo(executable+"/portable.txt").isFile()){s.data=executable+"/User";s.config=s.data+"/Config";}
    if(platform=="wii") {
        const auto args=s.installation.prefixArguments;
        for(int n=0;n<args.size();++n) {
            QString user;
            if((args[n]=="-u"||args[n]=="--user")&&n+1<args.size())user=args[++n];
            else if(args[n].startsWith("--user="))user=args[n].mid(7);
            if(!user.isEmpty()){s.data=user;s.config=user+"/Config";}
        }
    }
    return s;
}
QList<gamePreparation::File> requiredFiles(const Setup& s) {
    QList<gamePreparation::File> result;
    const auto add=[&](QString root,QString name,qint64 size=-1){result<<gamePreparation::File{s.platform+':'+name,s.platform,name,root,name,{},
        "Online only. Use files from your own console, all from the same console. Existing identity files are never replaced. The native emulator validates credentials on connection.",size,false};};
    if(s.platform=="n3ds") {
        QSettings ini(s.config+"/qt-config.ini",QSettings::IniFormat);
        const bool custom=!ini.value("Data Storage/use_custom_storage/default",false).toBool()&&ini.value("Data Storage/use_custom_storage",false).toBool();
        const auto nand=custom?ini.value("Data Storage/nand_directory").toString():s.data+"/nand";
        add(s.data,"sysdata/otp.bin",256);add(nand,"rw/sys/SecureInfo_A",0x111);add(nand,"rw/sys/LocalFriendCodeSeed_B",0x110);
    } else if(s.platform=="wiiu") {
        add(s.data,"otp.bin",1024);add(s.data,"seeprom.bin",512);
        const auto account=cemuAccount(s);
        if(QDir::isAbsolutePath(account.mlc))for(const auto* file:{"ccerts/WIIU_COMMON_1_CERT.der","ccerts/WIIU_COMMON_1_RSA_KEY.aes","ccerts/WIIU_ACCOUNT_1_CERT.der","ccerts/WIIU_ACCOUNT_1_RSA_KEY.aes","scerts/CACERT_NINTENDO_CA.der"})
            add(account.mlc+"/sys/title/0005001b/10054000/content",file);
    }
    return result;
}
QString check(const Setup& s,const std::function<void(const QString&)>& observe) {
    if(!services(s.platform).contains(s.service)||s.service=="off")return "Choose an Online service first.";
    const auto need=[&](const QString& path,qint64 size=-1){if(observe)observe(path);const QFileInfo f(path);return f.isFile()&&f.isReadable()&&f.size()>0&&(size<0||f.size()==size);};
    if(!need(s.installation.program)||!need(s.installation.runtimeFile)||!s.installation.platforms.contains(s.platform))return "Install the native emulator, then refresh game setup.";
    if(!QFileInfo(s.installation.program).isExecutable())return "The emulator launcher cannot be executed.";
    if(s.platform=="wiiu") {
        if(!need(s.config+"/settings.xml"))return "Open Cemu and prepare your own Pretendo account first.";
        const auto account=cemuAccount(s);
        if(account.id.isEmpty()||!account.pretendo)return "Select your PNID and Pretendo in Cemu > General settings > Account.";
        if(!QDir::isAbsolutePath(account.mlc))return "Choose an absolute MLC folder in Cemu first.";
        if(!need(s.data+"/otp.bin",1024)||!need(s.data+"/seeprom.bin",512))return "Import your own Wii U OTP and SEEPROM using the Cemu guide.";
        if(!need(account.mlc+"/usr/save/system/act/"+account.id+"/account.dat"))return "The selected Cemu account file is missing.";
        const auto certs=account.mlc+"/sys/title/0005001b/10054000/content";
        for(const auto* file:{"ccerts/WIIU_COMMON_1_CERT.der","ccerts/WIIU_COMMON_1_RSA_KEY.aes","ccerts/WIIU_ACCOUNT_1_CERT.der","ccerts/WIIU_ACCOUNT_1_RSA_KEY.aes","scerts/CACERT_NINTENDO_CA.der"})
            if(!need(certs+'/'+file))return "Import your own Wii U certificates using the Cemu guide. Cemu validates the full set on connection.";
    } else if(s.platform=="n3ds") {
        if(!need(s.config+"/qt-config.ini"))return "Complete Artic Setup and Nimbus setup in Azahar first.";
        QSettings ini(s.config+"/qt-config.ini",QSettings::IniFormat);
        if(ini.value("System/enable_required_online_lle_modules/default",false).toBool()||!ini.value("System/enable_required_online_lle_modules",false).toBool())return "Enable required LLE modules for online features in Azahar > System.";
        const bool custom=!ini.value("Data Storage/use_custom_storage/default",false).toBool()&&ini.value("Data Storage/use_custom_storage",false).toBool();
        const auto nand=custom?ini.value("Data Storage/nand_directory").toString():s.data+"/nand";
        if(!need(s.data+"/sysdata/otp.bin",256)||!need(nand+"/rw/sys/SecureInfo_A",0x111)||!need(nand+"/rw/sys/LocalFriendCodeSeed_B",0x110))return "Complete both Old and New 3DS Artic Setup with your own console.";
        const auto rules=s.data+"/sysdata/http_hle_replace_rules.txt";
        if(!need(rules))return "Open Nimbus in Azahar and select Pretendo.";
        const auto replacements=read(rules).replace("\r\n","\n").split('\n');
        for(const auto* pattern:{"nintendowifi\\.net","nintendo\\.net","pokemon-gl\\.com"}) {
            bool found=false;
            for(int n=0;n+1<replacements.size();n+=2)if(replacements[n]==pattern&&replacements[n+1]=="pretendo.cc")found=true;
            if(!found)return "Open Nimbus in Azahar and select Pretendo.";
        }
    } else {
        if(!need(s.config+"/Dolphin.ini"))return "Prepare Dolphin using the selected service's guide first.";
        QSettings ini(s.config+"/Dolphin.ini",QSettings::IniFormat);
        auto nand=ini.value("General/NANDRootPath").toString();if(nand.isEmpty())nand=s.data+"/Wii";
        if(!need(nand+"/shared2/sys/SYSCONF"))return "Import your own Wii NAND in Dolphin > Tools > Manage NAND.";
    }
    if(!s.prepared)return "Finish the provider guide, including game patches, then confirm preparation below.";
    return {};
}
QJsonObject identity(const AdventureRegistration& r,const Setup& s,const std::atomic_bool& cancel,const std::function<void(const QString&)>& observe) {
    if(r.adventure.platformId!=s.platform||r.adventure.collectionOnly||!check(s,observe).isEmpty()||cancel)return {};
    const auto suffix=QFileInfo(r.contentPath).suffix().toLower();
    const auto formats=s.platform=="wii"?QStringList{"iso","gcm","rvz","wia","wbfs","ciso","gcz","nfs"}:s.platform=="wiiu"?QStringList{"wud","wux","wua","rpx"}:QStringList{"3ds","cci","cxi","app","3dsx","zcci","zcxi","z3dsx","cia","zcia"};
    if(!formats.contains(suffix))return {};
    if(observe)observe(r.contentPath);
    const auto content=s.platform=="wii"?dolphin::contentIdentity(r.contentPath,16LL*1024*1024*1024,cancel,observe):retroarch::fileDigest(r.contentPath,32LL*1024*1024*1024,cancel);
    if(content.isEmpty()||cancel)return {};
    // Console IDs, native account IDs, NAND, paths and tokens are LOCAL ONLY.
    return {{"id","runtime.nintendo."+s.platform+'.'+s.service+".v1"},{"label",r.adventure.title.left(96)},
        {"content",content},{"runtime","native-online-v1"},{"settings","native-online-owned-v1"},{"service",s.service},
        {"players",4},{"lateJoin",false},{"privateProgress",false},{"temporaryProgress",false},{"connections",QJsonArray{"online"}}};
}
ProcessCommand command(const AdventureRegistration& r,const Setup& s,const QJsonObject& expected) {
    ProcessCommand cmd{s.installation.program,s.installation.prefixArguments,{}};cmd.emulatorRuntime=true;
    cmd.runtimeControls={{"kind",adapter(s.platform)},{"game",r.adventure.id}};
    cmd.prepare=[r,s,expected](ProcessCommand& out,const std::atomic_bool& cancel)->QString {
        const auto error=check(s);if(!error.isEmpty())return error;
        if(!sameMultiplayerGame(identity(r,s,cancel),expected))return "Your Online game or emulator changed. Leave the game party and start again.";
        auto lock=std::make_shared<QLockFile>(s.config+"/traineros-native-online.lock");
        lock->setStaleLockTime(0);if(!lock->tryLock())return "This native Online setup is already in use.";
        out.finalize=[lock](const ProcessOutcome&){lock->unlock();return QString();};
        if(s.platform=="wii")out.arguments<<"-b"<<"-C"<<"Dolphin.Display.Fullscreen=True"<<"-C"<<"Dolphin.Interface.ConfirmStop=False"<<"-e"<<r.contentPath;
        else if(s.platform=="wiiu") {const auto a=cemuAccount(s);out.arguments<<"-f"<<"-a"<<a.id<<"-m"<<a.mlc<<"-g"<<r.contentPath;}
        else {out.arguments<<"-f"<<r.contentPath;const auto e=azahar::prepareContent(out,r,cancel,s.config,s.data);if(!e.isEmpty())return e;}
        // Native save/account stores remain owned by the user's emulator. No peer
        // save seeding, account replacement, savestate or crash-time copyback.
        return {};
    };
    return cmd;
}
}
