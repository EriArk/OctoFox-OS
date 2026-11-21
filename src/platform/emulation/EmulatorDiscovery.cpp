#include "EmulatorDiscovery.h"
#include "RuntimePaths.h"
#include "core/input/RemoteGamePad.h"
#include "core/input/ControllerMappings.h"
#include <QSet>
#include <cstring>
#include <algorithm>
#include <QSaveFile>
#include <QRegularExpression>
#include <QXmlStreamWriter>
#include <QCryptographicHash>
#include "integrations/adventure/retroarch/RetroArchConfiguration.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QElapsedTimer>
#include <QStandardPaths>
#include <SDL.h>

namespace trainer {
namespace {
struct Route { QString id, app, binary; QStringList names, platforms; };
const QList<Route> routes{
    {"ppsspp", "org.ppsspp.PPSSPP", "PPSSPPSDL", {"PPSSPPSDL", "ppsspp"}, {"psp"}},
    {"armsx2", {}, "ARMSX2", {"ARMSX2", "armsx2"}, {"ps2"}},
    {"cemu", "info.cemu.Cemu", "Cemu", {"Cemu", "cemu"}, {"wiiu"}},
    {"duckstation", "org.duckstation.DuckStation", "duckstation-qt", {"duckstation-qt", "DuckStation", "duckstation"}, {"psx"}},
    {"rpcs3", {}, "rpcs3", {"rpcs3", "RPCS3"}, {"ps3"}},
    {"eden", {}, "eden", {"eden"}, {"switch"}},
    {"odamex", {}, "odamex", {"odamex"}, {"doom"}},
    {"supermodel", {}, "supermodel", {"supermodel"}, {"model3"}},
    {"xemu", "app.xemu.xemu", "xemu", {"xemu"}, {"xbox"}},
    {"melonds", "net.kuribo64.melonDS", "melonDS", {"melonDS"}, {"nds"}},
    {"azahar", "org.azahar_emu.Azahar", "azahar", {"azahar"}, {"n3ds"}},
    {"vita3k", {}, "vita3k", {"vita3k"}, {"psvita"}},
    {"dolphin", "org.DolphinEmu.dolphin-emu", "dolphin-emu", {"dolphin-emu"}, {"gc", "wii"}},
    {"retroarch", "org.libretro.RetroArch", "retroarch", {"retroarch"}, {}}
};
bool executable(const QString& path) {
    const QFileInfo f(path); return f.isAbsolute() && f.isFile() && f.isExecutable();
}
bool exists(const QString& path) { return QFileInfo::exists(path) || QFileInfo(path).isSymLink(); }
QJsonObject readProfile(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly) || f.size() > 65536) return {};
    const auto document = QJsonDocument::fromJson(f.readAll());
    return document.isObject() ? document.object() : QJsonObject{};
}
// Use the same discovered runtime and private HOME as play, without a game argument.
// Explicit user integration commands are never inferred or rewritten.
void describeSetup(QJsonObject& profile, const QString& id) {
    if(id=="odamex" || id=="supermodel")return; // These runtimes have no firmware GUI.
    auto program=profile["program"].toString();auto args=profile["prefixArguments"].toArray();
    if(!args.isEmpty() && args.first().toString().endsWith("/controller-bridge.py")) {
        int end=-1;for(int n=0;n<args.size();++n)if(args[n]=="--"){end=n;break;}
        if(end<0||end+1>=args.size())return;
        program=args[end+1].toString();QJsonArray rest;for(int n=end+2;n<args.size();++n)rest.append(args[n]);args=rest;
    }
    if(id=="vita3k") {
        const auto launcher=QFileInfo(program).canonicalFilePath();
        const auto root=QFileInfo(launcher).dir().absoluteFilePath("..");
        const auto manifest=readProfile(root+"/manifest.json");
        if(manifest["source"]!="46602447c7f84d53790b44e1869ab5105178bf16")return;
        const auto appDir=QDir(root).absoluteFilePath("runtime");
        const auto appRun=appDir+"/AppRun";
        if(!executable(appRun))return;
        // This extracted AppImage's AppRun silently exits without APPIMAGE.
        // Pass literal argv through env, retaining the runtime HOME supplied by
        // ProcessService. The full Qt frontend can install firmware and games;
        // the SDL frontend requires a title and cannot open setup on its own.
        program=QStandardPaths::findExecutable("env");
        args={"APPDIR="+appDir,"APPIMAGE="+appRun,appRun,"--frontend","qt"};
    }
    if(id=="retroarch" && !profile["configFile"].toString().isEmpty()){args.append("--config");args.append(profile["configFile"]);}
    if(!executable(program))return;
    profile["setupProgram"]=program;profile["setupArguments"]=args;
}
// Fresh defaults only. Existing preferences, including malformed files and
// symlinks, belong to their owner and are never overwritten by discovery.
bool seed(const QString& path, const QByteArray& bytes) {
    if (exists(path)) return QFileInfo(path).isFile();
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) return false;
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::NewOnly)) return false;
    if (file.write(bytes) == bytes.size() && file.flush()) return true;
    file.close(); file.remove(); return false;
}
// Adapt untouched generated configurations when the selected controller changes.
// A digest outside the emulator's config tree distinguishes our previous
// output from preferences subsequently saved by the emulator or its owner.
bool controllerConfig(const EmulatorEnvironment& env, const QString& path, const QByteArray& config) {
    if (!env.managed) return seed(path, config);
    if (QFileInfo(path).isSymLink()) return QFileInfo(path).isFile();
    const auto digest=[](const QByteArray& data){return QCryptographicHash::hash(data,QCryptographicHash::Sha256).toHex();};
    const auto directory=env.stateDirectory+"/integrations/managed/controller-defaults";
    const auto marker=directory+"/"+QString::fromLatin1(digest(path.toUtf8()));
    QFile current(path), previous(marker);
    if (exists(path)) {
        if (!current.open(QIODevice::ReadOnly) || current.size()>256*1024) return current.isOpen();
        const auto data=current.readAll();current.close();
        const auto known=previous.open(QIODevice::ReadOnly) ? previous.read(65) : QByteArray();
        previous.close();
        if (data!=config) {
            if (known!=digest(data)) return true;
            QSaveFile output(path);
            if (!output.open(QIODevice::WriteOnly) || output.write(config)!=config.size() || !output.commit()) return false;
        } else if (known==digest(config)) return true;
    } else if (!seed(path,config)) return false;
    if (!QDir().mkpath(directory)) return false;
    QSaveFile stamp(marker);
    const auto hash=digest(config);
    return stamp.open(QIODevice::WriteOnly) && stamp.write(hash)==hash.size() && stamp.commit();
}
QString runtime(const Route& route, const EmulatorEnvironment& env) {
    const auto location = env.flatpaks.value(route.app);
    return location.isEmpty() ? QString() : QDir(location).filePath("files/bin/" + route.binary);
}
QString configDirectory(const Route& route, bool flatpak, const EmulatorEnvironment& env) {
    const auto base = flatpak ? QDir(env.home).filePath(".var/app/" + route.app + "/config") : env.configHome;
    return QDir(base).filePath(route.id == "dolphin" ? "dolphin-emu" : route.id == "azahar" ? "azahar-emu" : route.id == "cemu" ? "Cemu" : route.id == "melonds" ? "melonDS" : route.id == "vita3k" ? "Vita3K" : route.id);
}
// RetroArch consults its user autoconfig tree when the private runtime
// starts. Seed the Linux drivers from that same installed Flatpak for built-in,
// USB and Bluetooth controllers, including pads connected after first boot.
void seedRetroArchPads(const EmulatorEnvironment& env, const QString& configDir, QStringList& notices) {
    const auto deployment = env.flatpaks.value("org.libretro.RetroArch");
    if (!env.managed || deployment.isEmpty()) return;
    const QDir catalogue(deployment + "/files/share/libretro/autoconfig");
    if (!catalogue.exists()) { notices << "retroarch: packaged controller profiles unavailable"; return; }
    for (const auto& driver : QStringList{"udev","sdl2","hid","linuxraw","x"}) {
        const QDir source(catalogue.filePath(driver));
        const auto profiles = source.entryList({"*.cfg"}, QDir::Files);
        if (profiles.isEmpty()) continue;
        const QDir destination(configDir + "/autoconfig/" + driver);
        if (QFileInfo(configDir + "/autoconfig").isSymLink() || QFileInfo(destination.path()).isSymLink()) continue;
        if (!destination.mkpath(".")) { notices << "retroarch: cannot prepare " + driver + " profiles"; continue; }
        const auto entries = destination.entryList(QDir::AllEntries | QDir::System | QDir::NoDotAndDotDot);
        const QSet<QString> existing(entries.cbegin(), entries.cend());
        for (const auto& name : profiles) {
            if (existing.contains(name)) continue;
            QFile profile(source.filePath(name));
            if (!profile.open(QIODevice::ReadOnly) || !seed(destination.filePath(name), profile.readAll()))
                notices << "retroarch: could not prepare controller profile " + name;
        }
    }
}
QByteArray dsDefaults(const EmulatorEnvironment& env) {
    QByteArray bytes = "# OctoFox OS initial controller defaults; future user edits are preserved.\n"
        "[Emu]\nDirectBoot = true\nExternalBIOSEnable = false\n"
        "[Instance0]\nJoystickID = " + QByteArray::number(env.controllerIndex) + "\n[Instance0.Joystick]\n";
    const QStringList keys{"A", "B", "X", "Y", "L", "R", "Start", "Select", "Up", "Down", "Left", "Right"};
    for (const auto& key : keys) bytes += key.toUtf8() + " = " + QByteArray::number(env.controllerButtons.value(key, -1)) + "\n";
    bytes += "[Instance0.Window0]\nScreenLayout = 2\n";
    return bytes;
}
QByteArray dolphinDefaults(const EmulatorEnvironment& env) {
    return "# OctoFox OS initial SDL controller; never replaced on update.\n[GCPad1]\nDevice = SDL/0/"
        + env.controllerName.toUtf8() + "\n"
        "Buttons/A = `Button E`\nButtons/B = `Button S`\nButtons/X = `Button N`\nButtons/Y = `Button W`\n"
        "Buttons/Z = `Shoulder R`\nButtons/Start = `Start`\n"
        "Main Stick/Up = `Left Y+`\nMain Stick/Down = `Left Y-`\nMain Stick/Left = `Left X-`\nMain Stick/Right = `Left X+`\n"
        "C-Stick/Up = `Right Y+`\nC-Stick/Down = `Right Y-`\nC-Stick/Left = `Right X-`\nC-Stick/Right = `Right X+`\n"
        "Triggers/L = `Trigger L` > 0.8\nTriggers/R = `Trigger R` > 0.8\n"
        "Triggers/L-Analog = `Trigger L`\nTriggers/R-Analog = `Trigger R`\n"
        "D-Pad/Up = `Pad N`\nD-Pad/Down = `Pad S`\nD-Pad/Left = `Pad W`\nD-Pad/Right = `Pad E`\n";
}
QByteArray cemuGamePad(const EmulatorEnvironment& env) {
    QByteArray bytes;
    QXmlStreamWriter xml(&bytes);
    xml.writeStartElement("emulated_controller");
    xml.writeTextElement("type","Wii U GamePad");
    xml.writeStartElement("controller");
    xml.writeTextElement("api","SDLController");
    xml.writeTextElement("uuid",env.cemuControllerUuid);
    xml.writeTextElement("display_name",env.controllerName);
    xml.writeStartElement("mappings");
    // Cemu 2.6 VPAD ButtonId order. Its SDL backend exposes normalized
    // buttons 0..14 and directions 38..47 for axes, rotation and triggers.
    const int inputs[]={env.switchPro?0:1,env.switchPro?1:0,env.switchPro?2:3,env.switchPro?3:2,
        9,10,42,43,6,4,11,12,13,14,7,8,45,39,44,38,47,41,46,40};
    int mapping=0;
    for (int button:inputs) {
        xml.writeStartElement("entry");
        xml.writeTextElement("mapping",QString::number(++mapping));
        xml.writeTextElement("button",QString::number(button));
        xml.writeEndElement();
    }
    xml.writeEndDocument();
    return bytes;
}
QByteArray wiiRemote(const EmulatorEnvironment& env) {
    return "[Wiimote1]\nSource = 1\nDevice = SDL/0/"+env.controllerName.toUtf8()+
        "\nButtons/A = `Button S`\nButtons/B = `Trigger R`\nButtons/1 = `Button W`\nButtons/2 = `Button E`"
        "\nButtons/- = Back\nButtons/+ = Start\nButtons/Home = Guide"
        "\nD-Pad/Up = `Pad N`\nD-Pad/Down = `Pad S`\nD-Pad/Left = `Pad W`\nD-Pad/Right = `Pad E`"
        "\nIR/Up = `Right Y+`\nIR/Down = `Right Y-`\nIR/Left = `Right X-`\nIR/Right = `Right X+`"
        "\nShake/X = `Thumb R`\nShake/Y = `Thumb R`\nShake/Z = `Thumb R`\nExtension = Nunchuk"
        "\nNunchuk/Buttons/C = `Shoulder L`\nNunchuk/Buttons/Z = `Trigger L`"
        "\nNunchuk/Stick/Up = `Left Y+`\nNunchuk/Stick/Down = `Left Y-`"
        "\nNunchuk/Stick/Left = `Left X-`\nNunchuk/Stick/Right = `Left X+`"
        "\nNunchuk/Shake/X = `Thumb L`\nNunchuk/Shake/Y = `Thumb L`\nNunchuk/Shake/Z = `Thumb L`\n";
}
// Keep DuckStation's factory keyboard bindings and other defaults. Its pinned
// Linux build creates a keyboard-only Pad1; native multi-bind uses repeated keys.
bool duckStationControls(const EmulatorEnvironment& env,const QString& directory) {
    const auto path=QDir(directory).filePath("settings.ini");
    if (!env.managed || QFileInfo(path).isSymLink()) return true;
    QFile factory(":/emulators/duckstation-defaults.ini");
    if (!factory.open(QIODevice::ReadOnly)) return false;
    const auto original=factory.readAll();
    const auto section=[](const QByteArray& ini) -> QByteArray {
        const auto marker=ini.indexOf("\n[Pad1]\n");
        if (marker<0 && !ini.startsWith("[Pad1]\n")) return {};
        const auto start=marker+1;
        const auto end=ini.indexOf("\n[",start+6);
        return ini.mid(start,end<0?-1:end-start).trimmed();
    };
    const auto stock=section(original);
    if (stock.isEmpty()) return false;
    const QMap<QByteArray,QByteArray> controls{
        {"Cross","A"},{"Circle","B"},{"Square","X"},{"Triangle","Y"},{"Start","Start"},{"Select","Back"},
        {"L1","LeftShoulder"},{"R1","RightShoulder"},{"L2","+LeftTrigger"},{"R2","+RightTrigger"},
        {"L3","LeftStick"},{"R3","RightStick"},{"Up","DPadUp"},{"Down","DPadDown"},{"Left","DPadLeft"},{"Right","DPadRight"},
        {"LLeft","-LeftX"},{"LRight","+LeftX"},{"LUp","-LeftY"},{"LDown","+LeftY"},
        {"RLeft","-RightX"},{"RRight","+RightX"},{"RUp","-RightY"},{"RDown","+RightY"}};
    const auto forPlayer=[&](int player) {
        auto mapped=stock;
        for (auto it=controls.cbegin();it!=controls.cend();++it)
            mapped+="\n"+it.key()+" = SDL-"+QByteArray::number(player)+"/"+it.value();
        return mapped;
    };
    auto mapped=forPlayer(env.playerIndex);
    auto prepared=[&] {
        auto fresh=original;
        fresh.replace("CheckAtStartup = true","CheckAtStartup = false"); // The runtime is maintained by OctoFox.
        fresh.replace("[Main]\n","[Main]\nNoDesktopFile = true\nSetupWizardIncomplete = false\n");
        const auto ra=QDir(env.home).filePath(".var/app/org.libretro.RetroArch/config/retroarch/retroarch.cfg");
        const auto bios=retroarch::configuredPath(retroarch::readSettings(ra),"system_directory",
            QDir::isAbsolutePath(env.libraryRoot)?QFileInfo(env.libraryRoot).dir().filePath("bios"):QString());
        if (retroarch::safePath(bios))
            fresh.replace("[BIOS]\n","[BIOS]\nSearchDirectory = "+bios.toUtf8()+"\n");
        return fresh.replace(stock,mapped);
    };
    if (!exists(path)) return seed(path,prepared());
    QFile existing(path);
    if (!existing.open(QIODevice::ReadOnly) || existing.size()>1024*1024) return false;
    const auto data=existing.readAll();existing.close();
    // Software 56 shipped factory settings plus bindings. Only migrate that
    // exact generated file; a wizard or preference edited by the owner wins.
    auto legacy=original;
    if (data==legacy.replace(stock,mapped) || data==original) {
        const auto next=prepared();
        QSaveFile output(path);
        return output.open(QIODevice::WriteOnly) && output.write(next)==next.size() && output.commit();
    }
    // DuckStation can sort keys on exit. Compare the complete binding set
    // before changing the old device number, leaving custom controls intact.
    const bool crlf=data.contains("\r\n");
    const auto current=section(QByteArray(data).replace("\r\n","\n"));
    if (current.isEmpty()) return true;
    if (current!=stock) {
        static const QRegularExpression slot(" = SDL-([0-9]{1,3})/");
        const auto previous=slot.match(QString::fromUtf8(current));
        if (!previous.hasMatch()) return true;
        const auto old=previous.captured(1).toInt();
        if (old==env.playerIndex || env.controllerName.isEmpty()) return true;
        auto ours=forPlayer(old).split('\n'), found=current.split('\n');
        std::sort(ours.begin(),ours.end());std::sort(found.begin(),found.end());
        if (ours!=found) return true;
    }
    auto changed=data;
    changed.replace(crlf?QByteArray(current).replace("\n","\r\n"):current,crlf?mapped.replace("\n","\r\n"):mapped);
    QSaveFile output(path);
    return output.open(QIODevice::WriteOnly) && output.write(changed)==changed.size() && output.commit();
}
void controllerDefaults(const Route& route, const QString& configDir, const EmulatorEnvironment& env, QStringList& notices) {
    if (route.id=="duckstation" && !duckStationControls(env,configDir)) notices << "duckstation: PS1 controller settings unavailable";
    if (route.id == "retroarch") seedRetroArchPads(env, configDir, notices);
    if (route.id == "rpcs3") {
        // OctoFox OS already confirms Exit; leave existing desktop preferences alone.
        if (!seed(QDir(configDir).filePath("GuiConfigs/CurrentSettings.ini"),
                  "[main_window]\ninfoBoxEnabledWelcome=false\nconfirmationBoxExitGame=false\n"))
            notices << "rpcs3: initial window settings unavailable";
        if (!seed(QDir(configDir).filePath("config.yml"),
                  "Video:\n  Renderer: Vulkan\n  Shader Mode: Async Recompiler (multi-threaded)\n"))
            notices << "rpcs3: initial renderer settings unavailable";
    } else if (route.id == "cemu" && !env.cemuControllerUuid.isEmpty()) {
        // Older discovery records used a lowercase directory. Cemu uses Cemu
        // under XDG_CONFIG_HOME in both the AppImage and Flatpak.
        const auto path=QFileInfo(configDir).dir().filePath("Cemu/controllerProfiles/controller0.xml");
        if (!controllerConfig(env,path,cemuGamePad(env))) notices << "cemu: Wii U GamePad profile unavailable";
    } else if (route.id == "eden") {
        if (env.switchBindings.isEmpty()) return;
        QByteArray bytes = "[Controls]\nplayer_0_connected=true\nplayer_0_connected\\default=false\n";
        for (auto it=env.switchBindings.cbegin(); it!=env.switchBindings.cend(); ++it)
            bytes += "player_0_" + it.key().toUtf8() + "=\"" + it.value().toUtf8()
                + "\"\nplayer_0_" + it.key().toUtf8() + "\\default=false\n";
        if (!controllerConfig(env,QDir(configDir).filePath("qt-config.ini"),bytes)) notices << "eden: initial controls unavailable";
    } else if (route.id == "azahar") {
        const auto config = QDir(configDir).filePath("qt-config.ini");
        QByteArray bytes="[UI]\nfirstStart=false\nfirstStart\\default=false\nconfirmClose=false\nconfirmClose\\default=false\n"
            "[Renderer]\ngraphics_api=2\ngraphics_api\\default=false\nresolution_factor=1\nresolution_factor\\default=false\n"
            "[Layout]\nlayout_option=3\nlayout_option\\default=false\n"
            "[Controls]\nprofiles\\size=1\nprofiles\\1\\name=TrainerOS\nprofiles\\1\\input_maptype=2\n";
        const QMap<QByteArray,int> buttons{{"a",SDL_CONTROLLER_BUTTON_B},{"b",SDL_CONTROLLER_BUTTON_A},
            {"x",SDL_CONTROLLER_BUTTON_Y},{"y",SDL_CONTROLLER_BUTTON_X},{"l",SDL_CONTROLLER_BUTTON_LEFTSHOULDER},
            {"r",SDL_CONTROLLER_BUTTON_RIGHTSHOULDER},{"start",SDL_CONTROLLER_BUTTON_START},{"select",SDL_CONTROLLER_BUTTON_BACK},
            {"up",SDL_CONTROLLER_BUTTON_DPAD_UP},{"down",SDL_CONTROLLER_BUTTON_DPAD_DOWN},
            {"left",SDL_CONTROLLER_BUTTON_DPAD_LEFT},{"right",SDL_CONTROLLER_BUTTON_DPAD_RIGHT}};
        for(auto it=buttons.cbegin();it!=buttons.cend();++it)bytes+="profiles\\1\\button_"+it.key()+"=\"api:controller,button:"
            +QByteArray::number(it.value())+",engine:sdl,maptype:all,port:0\"\nprofiles\\1\\button_"+it.key()+"\\default=false\n";
        bytes+="profiles\\1\\circle_pad=\"api:controller,axis_x:0,axis_y:1,engine:sdl,maptype:all,port:0\"\nprofiles\\1\\circle_pad\\default=false\n"
            "profiles\\1\\c_stick=\"api:controller,axis_x:2,axis_y:3,engine:sdl,maptype:all,port:0\"\nprofiles\\1\\c_stick\\default=false\n"
            "profiles\\1\\button_zl=\"api:controller,axis:4,direction:+,engine:sdl,maptype:all,port:0,threshold:0.5\"\nprofiles\\1\\button_zl\\default=false\n"
            "profiles\\1\\button_zr=\"api:controller,axis:5,direction:+,engine:sdl,maptype:all,port:0,threshold:0.5\"\nprofiles\\1\\button_zr\\default=false\n";
        if(!seed(config,bytes))notices<<"azahar: initial controls unavailable";
    } else if (route.id == "melonds") {
        const auto config = QDir(configDir).filePath("melonDS.toml");
        if (env.controllerButtons.size() == 12 && !controllerConfig(env,config,dsDefaults(env))) notices << "melonds: initial controls unavailable";
        if (!exists(config)) notices << "melonds: controller defaults need a connected SDL controller";
    } else if (route.id == "dolphin") {
        const auto config = QDir(configDir).filePath("GCPadNew.ini");
        if (!env.controllerName.isEmpty() && !env.controllerName.contains(QRegularExpression("[\\x00-\\x1f\\x7f]"))) {
            if (!controllerConfig(env,config,dolphinDefaults(env))) notices << "dolphin: GameCube controls unavailable";
            if (!controllerConfig(env,QDir(configDir).filePath("WiimoteNew.ini"),wiiRemote(env)))
                notices << "dolphin: Wii Remote controls unavailable";
        }
        if (!exists(config)) notices << "dolphin: GameCube controls need a connected SDL controller";
    }
}
void describeControllerProfile(const Route& route,const QString& configDir,const EmulatorEnvironment& env,
                               QJsonObject& profile,QStringList& notices) {
    if (route.id == "rpcs3" && !env.controllerName.isEmpty()) {
        // Separate named input profile: keep the user's global mapping
        // (often Steam Virtual Gamepad) intact outside OctoFox OS.
        auto device=QJsonDocument(QJsonArray{env.controllerName+" 1"}).toJson(QJsonDocument::Compact);
        device=device.mid(1,device.size()-2); // JSON string is also a YAML quoted scalar.
        QByteArray bytes="Player 1 Input:\n  Handler: SDL\n  Device: "+device+"\n  Config:\n"
            "    Left Stick Left: LS X-\n    Left Stick Right: LS X+\n    Left Stick Up: LS Y+\n    Left Stick Down: LS Y-\n"
            "    Right Stick Left: RS X-\n    Right Stick Right: RS X+\n    Right Stick Up: RS Y+\n    Right Stick Down: RS Y-\n"
            "    Cross: South\n    Circle: East\n    Square: West\n    Triangle: North\n"
            "    Up: Up\n    Down: Down\n    Left: Left\n    Right: Right\n"
            "    Start: Start\n    Select: Back\n    PS Button: Guide\n"
            "    L1: LB\n    R1: RB\n    L2: LT\n    R2: RT\n    L3: LS\n    R3: RS\n";
        for (int player=2;player<=7;++player)
            bytes+="Player "+QByteArray::number(player)+" Input:\n  Handler: \"Null\"\n  Device: \"Null\"\n";
        if (controllerConfig(env,QDir(configDir).filePath("input_configs/global/TrainerOS.yml"),bytes)) {
            auto arguments=profile["prefixArguments"].toArray();
            if (arguments.contains("--input-config")) return;
            arguments.append("--input-config"); arguments.append("TrainerOS");
            profile["prefixArguments"]=arguments;
        } else notices << "rpcs3: initial controls unavailable";
    }
    if (route.id == "melonds" && QFileInfo(configDir + "/melonDS.toml").isFile()) {
        profile["configFile"] = configDir + "/melonDS.toml";
        profile["backupProtocol"] = "melonds-sav-v1";
    }
}

}
QString currentFlatpakDeployment(const QString& app, const QStringList& installations) {
    for (const auto& installation : installations) {
        const auto active = QDir(installation).filePath("app/" + app + "/current/active");
        if (QFileInfo(active).isDir() && QFileInfo(QDir(active).filePath("metadata")).isFile())
            return active;
    }
    return {};
}
EmulatorEnvironment installedEmulators(const QString& stateDirectory, const QString& libraryRoot, bool readController) {
    EmulatorEnvironment env;
    env.home = QDir::homePath(); env.configHome = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    env.managed = !runtimepaths::home().isEmpty();
    if (env.managed) { env.home = runtimepaths::home(); env.configHome = env.home + "/.config"; }
    env.stateDirectory = stateDirectory; env.libraryRoot = libraryRoot;
#ifdef Q_OS_LINUX
    if (!env.managed) env.nativeCoreDirectories = {"/usr/lib/libretro", "/usr/lib64/libretro", "/usr/lib/aarch64-linux-gnu/libretro"};
    if (!env.managed) for (const auto& route : routes) for (const auto& name : route.names) {
        const auto path = QStandardPaths::findExecutable(name);
        if (!path.isEmpty()) env.executables.insert(name, path);
    }
    env.executables.insert("python3", QStandardPaths::findExecutable("python3"));
    const auto flatpak = QStandardPaths::findExecutable("flatpak");
    if (!flatpak.isEmpty()) {
        env.executables.insert("flatpak", flatpak);
        QElapsedTimer deadline; deadline.start();
        for (const auto& route : routes) {
            if (route.app.isEmpty() || deadline.elapsed() >= 2000) continue;
            if (env.managed) {
                const auto location = currentFlatpakDeployment(route.app, {env.home + "/.local/share/flatpak"});
                if (!location.isEmpty()) env.flatpaks.insert(route.app, location);
                continue;
            }
            QProcess process; process.start(flatpak, {"info", "--show-location", route.app});
            if (!process.waitForFinished(qMax(1, 2000 - int(deadline.elapsed())))) { process.kill(); process.waitForFinished(100); continue; }
            if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
                // `run APP` uses current, but `info APP` rejects multiple branches.
                // Preserve the rollback branch and follow the user's selection.
                const auto location = currentFlatpakDeployment(route.app, {
                    qEnvironmentVariable("FLATPAK_USER_DIR", QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)).filePath("flatpak")),
                    qEnvironmentVariable("FLATPAK_SYSTEM_DIR", "/var/lib/flatpak")});
                if (!location.isEmpty()) env.flatpaks.insert(route.app, location);
                continue;
            }
            auto location = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
            if (!QDir::isAbsolutePath(location) || location.contains('\n')) continue;
            // Keep Flatpak's stable active link where available. No hash-specific
            // runtime identity survives an upstream package update.
            const auto active = QFileInfo(location).dir().filePath("active");
            if (QFileInfo(active).canonicalFilePath() == QFileInfo(location).canonicalFilePath()) location = active;
            env.flatpaks.insert(route.app, location);
        }
    }
    for (const auto& route : routes) {
        if (env.managed) {
            const QHash<QString, QString> bundles{{"odamex","odamex"},{"supermodel","supermodel-link"},
                {"xemu","xemu-lan"},{"vita3k","vita3k-netplay"}};
            if (bundles.contains(route.id)) {
                const auto path = env.home + "/.local/share/TrainerOS/emulators/" + bundles[route.id]
                    + (route.id == "xemu" ? "/xemu.AppImage" : "/bin/" + route.binary);
                if (executable(path)) env.executables.insert(route.names.first(), path);
            }
        }
        const auto appImage = QDir(env.home).filePath("Applications/" + route.binary + ".AppImage");
        if (!env.executables.contains(route.names.first()) && executable(appImage)) env.executables.insert(route.names.first(), appImage);
        if(route.id=="duckstation" && !env.executables.contains(route.names.first())) {
            const auto image=QDir(env.home).filePath("Applications/DuckStation.AppImage");
            if(executable(image))env.executables.insert(route.names.first(),image);
        }
        if (route.id=="azahar" && env.managed) {
            const auto image=env.home+"/Applications/Azahar-Enhanced.AppImage";
            if(executable(image))env.executables.insert(route.names.first(),image);
        }
    }
    if (readController) readEmulatorController(env);
#endif
    return env;
}
void readEmulatorController(EmulatorEnvironment& env, int preferredInstance) {
#ifdef Q_OS_LINUX
    env.controllerIndex=0;env.playerIndex=0;env.kernelPadName.clear();env.padVendor=0;env.padProduct=0;
    env.cemuControllerUuid.clear();env.switchPro=false;
    env.controllerName.clear();
    env.controllerButtons.clear();
    env.switchBindings.clear();
    const bool newSubsystem=SDL_WasInit(SDL_INIT_GAMECONTROLLER)==0;
    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) != 0) return;
    if (newSubsystem) loadPackagedControllerMappings();
    for (int index=0;index<SDL_NumJoysticks();++index) {
        if (preferredInstance>=0 && SDL_JoystickGetDeviceInstanceID(index)!=preferredInstance) continue;
        if (!SDL_IsGameController(index) || isRemoteGamePad(index)) continue;
        auto* pad=SDL_GameControllerOpen(index);
        if (!pad) continue;
        env.controllerIndex=index;
        env.playerIndex=qMax(0,SDL_GameControllerGetPlayerIndex(pad));
        env.kernelPadName=QString::fromStdString(kernelGamePadName(index));
        env.padVendor=SDL_JoystickGetDeviceVendor(index);env.padProduct=SDL_JoystickGetDeviceProduct(index);
        env.controllerName = QString::fromUtf8(SDL_GameControllerName(pad));
        char guid[33]{};
        auto switchGuid=SDL_JoystickGetGUID(SDL_GameControllerGetJoystick(pad));
        SDL_JoystickGetGUIDString(switchGuid,guid,sizeof(guid));
        int sameGuidIndex=0;
        for (int other=0;other<index;++other) {
            const auto otherGuid=SDL_JoystickGetDeviceGUID(other);
            if (SDL_IsGameController(other) && std::memcmp(otherGuid.data,switchGuid.data,sizeof(switchGuid.data))==0) ++sameGuidIndex;
        }
        env.cemuControllerUuid=QString::number(sameGuidIndex)+"_"+QString::fromLatin1(guid);
        env.switchPro=SDL_GameControllerGetType(pad)==SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_PRO;
        // Eden ignores SDL's controller-name CRC when identifying a device.
        switchGuid.data[2]=switchGuid.data[3]=0;
        SDL_JoystickGetGUIDString(switchGuid,guid,sizeof(guid));
        const QString prefix = "engine:sdl,port:0,guid:" + QString::fromLatin1(guid);
        const auto bind = [&](const QString& key, SDL_GameControllerButtonBind binding) {
            QString value;
            if (binding.bindType == SDL_CONTROLLER_BINDTYPE_BUTTON)
                value = ",button:" + QString::number(binding.value.button);
            else if (binding.bindType == SDL_CONTROLLER_BINDTYPE_AXIS)
                value = ",axis:" + QString::number(binding.value.axis) + ",threshold:0.5,invert:+";
            else if (binding.bindType == SDL_CONTROLLER_BINDTYPE_HAT) {
                const QHash<int,QString> directions{{SDL_HAT_UP,"up"},{SDL_HAT_DOWN,"down"},{SDL_HAT_LEFT,"left"},{SDL_HAT_RIGHT,"right"}};
                const auto direction = directions.value(binding.value.hat.hat_mask);
                if (!direction.isEmpty()) value = ",hat:" + QString::number(binding.value.hat.hat) + ",direction:" + direction;
            }
            if (!value.isEmpty()) env.switchBindings.insert("button_"+key,prefix+value);
        };
        const QList<QPair<QString,SDL_GameControllerButton>> switchButtons{
            {"a",SDL_CONTROLLER_BUTTON_B},{"b",SDL_CONTROLLER_BUTTON_A},
            {"x",SDL_CONTROLLER_BUTTON_Y},{"y",SDL_CONTROLLER_BUTTON_X},
            {"l",SDL_CONTROLLER_BUTTON_LEFTSHOULDER},{"r",SDL_CONTROLLER_BUTTON_RIGHTSHOULDER},
            {"plus",SDL_CONTROLLER_BUTTON_START},{"minus",SDL_CONTROLLER_BUTTON_BACK},
            {"lstick",SDL_CONTROLLER_BUTTON_LEFTSTICK},{"rstick",SDL_CONTROLLER_BUTTON_RIGHTSTICK},
            {"dup",SDL_CONTROLLER_BUTTON_DPAD_UP},{"ddown",SDL_CONTROLLER_BUTTON_DPAD_DOWN},
            {"dleft",SDL_CONTROLLER_BUTTON_DPAD_LEFT},{"dright",SDL_CONTROLLER_BUTTON_DPAD_RIGHT}};
        for (const auto& [key,button] : switchButtons) bind(key,SDL_GameControllerGetBindForButton(pad,button));
        bind("zl",SDL_GameControllerGetBindForAxis(pad,SDL_CONTROLLER_AXIS_TRIGGERLEFT));
        bind("zr",SDL_GameControllerGetBindForAxis(pad,SDL_CONTROLLER_AXIS_TRIGGERRIGHT));
        for (int stick=0; stick<2; ++stick) {
            const auto x=SDL_GameControllerGetBindForAxis(pad,stick==0?SDL_CONTROLLER_AXIS_LEFTX:SDL_CONTROLLER_AXIS_RIGHTX);
            const auto y=SDL_GameControllerGetBindForAxis(pad,stick==0?SDL_CONTROLLER_AXIS_LEFTY:SDL_CONTROLLER_AXIS_RIGHTY);
            if (x.bindType==SDL_CONTROLLER_BINDTYPE_AXIS && y.bindType==SDL_CONTROLLER_BINDTYPE_AXIS)
                env.switchBindings.insert(stick==0?"lstick":"rstick",prefix+",axis_x:"+QString::number(x.value.axis)
                    +",axis_y:"+QString::number(y.value.axis)+",deadzone:0.15,range:1.0");
        }
        const QList<QPair<QString, SDL_GameControllerButton>> buttons{
            {"A",SDL_CONTROLLER_BUTTON_B},{"B",SDL_CONTROLLER_BUTTON_A},{"X",SDL_CONTROLLER_BUTTON_Y},{"Y",SDL_CONTROLLER_BUTTON_X},
            {"L",SDL_CONTROLLER_BUTTON_LEFTSHOULDER},{"R",SDL_CONTROLLER_BUTTON_RIGHTSHOULDER},
            {"Start",SDL_CONTROLLER_BUTTON_START},{"Select",SDL_CONTROLLER_BUTTON_BACK},
            {"Up",SDL_CONTROLLER_BUTTON_DPAD_UP},{"Down",SDL_CONTROLLER_BUTTON_DPAD_DOWN},
            {"Left",SDL_CONTROLLER_BUTTON_DPAD_LEFT},{"Right",SDL_CONTROLLER_BUTTON_DPAD_RIGHT}};
        for (const auto& [name, key] : buttons) {
            const auto binding = SDL_GameControllerGetBindForButton(pad, key);
            if (binding.bindType == SDL_CONTROLLER_BINDTYPE_BUTTON) env.controllerButtons.insert(name, binding.value.button);
            else if (binding.bindType == SDL_CONTROLLER_BINDTYPE_HAT)
                env.controllerButtons.insert(name, 0x100 | (binding.value.hat.hat << 4) | binding.value.hat.hat_mask);
        }
        SDL_GameControllerClose(pad);
        break;
    }
    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
#else
    Q_UNUSED(env);
    Q_UNUSED(preferredInstance);
#endif
}
EmulatorDiscovery prepareEmulators(const EmulatorEnvironment& env) {
    EmulatorDiscovery result;
    if (env.stateDirectory.isEmpty()) return result;
    for (const auto& route : routes) {
        const auto profileRoot = env.stateDirectory + (env.managed ? "/integrations/managed" : "/integrations");
        const auto explicitPath = profileRoot + "/" + route.id + ".json";
        const auto discoveredPath = profileRoot + "/discovered/" + route.id + ".json";
        const bool supplied = exists(explicitPath), previous = exists(discoveredPath);
        auto profile = readProfile(supplied ? explicitPath : discoveredPath);
        if (supplied || previous) {
            if (profile["version"].toInt() != 1) { result.notices << route.id + ": existing integration is unreadable; kept unchanged"; continue; }
            // Repair only the declared Flatpak runtime, never its launcher,
            // wrapper, arguments, config/save locations or selected emulator.
            const auto arguments = profile["prefixArguments"].toArray().toVariantList();
            const auto oldRuntime = profile["runtimeFile"].toString();
            const auto currentRuntime = runtime(route, env);
            const auto flatpakIndex = arguments.indexOf(route.app);
            if (!route.app.isEmpty() && flatpakIndex > 0 && arguments[flatpakIndex - 1] == "run"
                && oldRuntime.contains("/app/" + route.app + "/") && oldRuntime.endsWith("/files/bin/" + route.binary)
                && executable(currentRuntime)) profile["runtimeFile"] = currentRuntime;
            if (!supplied && QDir::isAbsolutePath(profile["initialConfigDirectory"].toString())) {
                const auto directory=profile["initialConfigDirectory"].toString();
                controllerDefaults(route,directory,env,result.notices);
                describeControllerProfile(route,directory,env,profile,result.notices);
            }
            if(!supplied)describeSetup(profile,route.id);
            result.profiles.insert(route.id, profile);
            continue;
        }
        QString program;
        for (const auto& name : route.names) if (executable(env.executables.value(name))) { program = env.executables.value(name); break; }
        // The graphical Armada session has a deliberately short PATH. A
        // selected per-user launcher must still be discoverable there, while
        // explicit profiles and binaries already found on PATH keep priority.
        if (program.isEmpty() && !env.managed) for (const auto& name : route.names) {
            const auto local = QStandardPaths::findExecutable(name,
                {QDir(env.home).filePath(".local/bin")});
            if (executable(local)) { program = local; break; }
        }
        QJsonArray arguments;
        QString runtimeFile = program;
        const bool flatpak = program.isEmpty() && executable(env.executables.value("flatpak")) && executable(runtime(route, env));
        if (flatpak) { program = env.executables.value("flatpak"); runtimeFile = runtime(route, env); arguments = {"run", route.app}; }
        if (flatpak && env.managed) arguments = {"--user", "run", route.app};
        if (program.isEmpty()) continue;
        if(route.id=="vita3k") {
            // A .psvita link is an installed-title reference, not a native CLI
            // image argument. Only discover the maintained launcher here.
            const auto launcher=QFileInfo(program).canonicalFilePath();
            const auto manifest=readProfile(QFileInfo(launcher).dir().filePath("../manifest.json"));
            if(manifest["protocol"]!=1||manifest["source"]!="46602447c7f84d53790b44e1869ab5105178bf16"||manifest["settings"]!="native-lan-two-owned-v1")continue;
        }
        if (route.id == "odamex") {
            const auto launcher=QFileInfo(program).canonicalFilePath();
            const auto manifest=readProfile(QFileInfo(launcher).dir().filePath("../manifest.json"));
            if(manifest["protocol"]!=1||manifest["source"]!="3a763534ac609aee8d22351baa3155809c4ea355"||manifest["settings"]!="odamex-owned-native-v1")continue;
        }
        if ((route.id == "melonds" || route.id == "dolphin" || route.id == "azahar" || route.id == "vita3k" || route.id == "cemu" || route.id == "duckstation" || route.id == "rpcs3" || route.id == "eden" || route.id == "xemu" || route.id == "supermodel" || route.id == "odamex") && executable(env.executables.value("python3"))) {
            const QStringList helpers{QDir(env.home).filePath(".local/libexec/traineros/controller-bridge.py"),
                "/var/opt/traineros/integrations/controller-bridge.py"};
            for (const auto& helper : helpers) if (QFileInfo(helper).isFile()) {
                QJsonArray wrapped{helper};
                if (route.id == "melonds" || route.id == "azahar" || route.id == "vita3k" || route.id == "cemu") wrapped.append("--pointer");
                wrapped.append("--"); wrapped.append(program);
                for (const auto& value : arguments) wrapped.append(value);
                arguments = wrapped; program = env.executables.value("python3"); break;
            }
        }
        profile = {{"version",1},{"adapter",route.id},{"program",program},{"runtimeFile",runtimeFile},
            {"prefixArguments",arguments},{"validatedPlatforms",QJsonArray::fromStringList(route.platforms)}};
        const auto configDir = configDirectory(route, flatpak, env);
        profile["initialConfigDirectory"] = configDir;
        if (route.id == "retroarch") {
            const auto config = QDir(configDir).filePath("retroarch.cfg");
            const auto saves = QDir(configDir).filePath("saves");
            const auto bios = QFileInfo(env.libraryRoot).dir().filePath("bios");
            if (!retroarch::safePath(saves) || !retroarch::safePath(bios)) continue;
            const auto bytes = QByteArray("# OctoFox OS initial defaults; preserve user edits.\n")
                + "input_driver = \"sdl2\"\ninput_joypad_driver = \"sdl2\"\ninput_autodetect_enable = \"true\"\n"
                + "video_fullscreen = \"true\"\nconfig_save_on_exit = \"false\"\n"
                + "savestate_auto_load = \"false\"\nsavestate_auto_save = \"false\"\n"
                + "savefile_directory = \"" + saves.toUtf8() + "\"\nsystem_directory = \"" + bios.toUtf8() + "\"\n"
                + "savefiles_in_content_dir = \"false\"\nsort_savefiles_enable = \"false\"\nsort_savefiles_by_content_enable = \"false\"\n";
            const bool fresh = !exists(config);
            if (fresh && !QDir().mkpath(saves)) { result.notices << "retroarch: could not prepare save directory"; continue; }
            if (!seed(config, bytes)) { result.notices << "retroarch: could not prepare initial settings"; continue; }
            if (flatpak) seedRetroArchPads(env, configDir, result.notices);
            const auto settings = retroarch::readSettings(config);
            auto cores = retroarch::configuredPath(settings,"libretro_directory",QDir(configDir).filePath("cores"));
            if (!flatpak && QDir(cores).entryList({"*_libretro.so"},QDir::Files).isEmpty()) {
                for (const auto& candidate : env.nativeCoreDirectories)
                    if (!QDir(candidate).entryList({"*_libretro.so"},QDir::Files).isEmpty()) { cores = candidate; break; }
            }
            profile["configFile"] = config; profile["coresDirectory"] = cores;
            profile["backupProtocol"] = "mgba-sram-v1"; // Existing runtime checks still gate save ownership.
        } else {
            controllerDefaults(route, configDir, env, result.notices);
            describeControllerProfile(route,configDir,env,profile,result.notices);
        }
        // Persist the selected runtime family once. Installing a different
        // emulator later must not silently move existing games to different saves.
        describeSetup(profile,route.id);
        if (!seed(discoveredPath,QJsonDocument(profile).toJson())) { result.notices << route.id + ": could not retain discovered route"; continue; }
        result.profiles.insert(route.id, profile);
    }
    // The adapter consumes this live local observation. Never persist a device
    // identity in a game, an integration file, or a network invitation.
    auto ra=result.profiles.find("retroarch");
    if (env.managed && ra!=result.profiles.end() && !env.controllerName.isEmpty()
        && ra.value().contains("initialConfigDirectory"))
        ra.value()["localPad"]=QJsonObject{{"name",env.kernelPadName},{"sdlName",env.controllerName},{"vendor",env.padVendor},{"product",env.padProduct}};
    return result;
}
}
