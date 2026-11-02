#pragma once
#include "core/navigation/ShellController.h"
#include <QQuickWindow>
#include <QQuickItem>
#include <QTemporaryDir>
#include <QJsonDocument>
#include <QJsonArray>
#include <QTimer>
#include <QImage>
#include <QSettings>
#include "../CartridgeArchiveFixture.h"
#include <QtTest/QTest>
#include <memory>

inline void startGamePreparationSmoke(QQuickWindow* window,trainer::ShellController& shell,const QString& output,
        bool& completed,int& warnings,QStringList& diagnostics) {
    auto dir=std::make_shared<QTemporaryDir>();auto stage=std::make_shared<int>(0);auto ticks=std::make_shared<int>(0);
    auto selectedFile=std::make_shared<int>(0);
    QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,dir->path());
    const auto write=[](const QString& path,const QByteArray& bytes){QDir().mkpath(QFileInfo(path).absolutePath());QFile f(path);return f.open(QIODevice::WriteOnly)&&f.write(bytes)==bytes.size();};
    const auto runtime=dir->path()+"/bin/azahar.exe";write(runtime,"fixture");QFile(runtime).setPermissions(QFile::ReadOwner|QFile::WriteOwner|QFile::ExeOwner);
    QDir().mkpath(dir->path()+"/bin/user");write(dir->path()+"/input/otp.bin",QByteArray(256,'x'));
    const QJsonObject profile{{"version",1},{"adapter","azahar"},{"program",QCoreApplication::applicationFilePath()},{"runtimeFile",runtime},{"validatedPlatforms",QJsonArray{"n3ds"}},{"prefixArguments",QJsonArray{}}};
    write(dir->path()+"/integrations/azahar.json",QJsonDocument(profile).toJson());
    write(dir->path()+"/cores/mgba_libretro.so","fixture");write(dir->path()+"/cores/fceumm_libretro.so","fixture");write(dir->path()+"/cores/pcsx_rearmed_libretro.so","fixture");
    write(dir->path()+"/retroarch.cfg",("system_directory = \""+dir->path()+"/bios\"\n").toUtf8());
    const QJsonObject retro{{"program",QCoreApplication::applicationFilePath()},{"configFile",dir->path()+"/retroarch.cfg"},{"coresDirectory",dir->path()+"/cores"}};
    write(dir->path()+"/input/pack.zip",cartridgeArchive("zip",{{"mixed/otp.bin",QByteArray(256,'x')},{"mixed/SecureInfo_A",QByteArray(0x111,'a')},{"mixed/LocalFriendCodeSeed_B",QByteArray(0x110,'b')}}));
    shell.gamePreparation()->configure(dir->path(),{{"azahar",profile},{"retroarch",retro}});shell.gamePreparation()->canImport=[] {return true;};shell.settings()->configureNintendoOnline(dir->path());
    auto timer=new QTimer(window);timer->setInterval(250);
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&completed,&warnings,&diagnostics]{
        const auto check=[&](bool ok,QString error){if(!ok)diagnostics<<error;};
        const auto capture=[&](QString name){check(window->grabWindow().save(output+'/'+name+".png"),"Could not capture "+name);};
        auto* f=shell.gamePreparation();
        if(++*ticks>100){diagnostics<<"Preparation smoke timeout";timer->stop();completed=true;QCoreApplication::exit(1);return;}
        if(f->busy()||f->picker()->busy())return;
        switch((*stage)++) {
        case 0: window->resize(960,540);shell.systemAction("settings");shell.settings()->selectPage("library",true);shell.settings()->activateRow(shell.settings()->controls().size()-1);break;
        case 1: {
            check(shell.service()=="game-preparation","Settings opens preparation");f->selectGroup("n3ds");
            int found=-1;for(int n=0;n<f->fileRows().size();++n)if(f->fileRows()[n].toMap()["filename"]=="sysdata/otp.bin")found=n;
            check(found>=0,"Own console file appears");*selectedFile=found;shell.dispatch(trainer::Action::Right);for(int n=0;n<found;++n)shell.dispatch(trainer::Action::Down);check(f->focusIndex()==1000+found,"Controller reaches the file and scrolls it into view");break;
        }
        case 2: {
            capture("missing-file-960");const auto name="game-preparation-import-"+QString::number(*selectedFile);
            std::function<QQuickItem*(QQuickItem*)> find=[&](QQuickItem* p)->QQuickItem*{if(p->objectName()==name)return p;for(auto* child:p->childItems())if(auto* result=find(child))return result;return nullptr;};
            auto* item=find(window->contentItem());check(item&&item->isVisible(),"Import touch target is visible");if(item)QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,item->mapToScene(QPointF(item->width()/2,item->height()/2)).toPoint());
            check(f->picker()->isOpen(),"Touch opens shared file picker");f->picker()->navigate(dir->path()+"/input");break;
        }
        case 3: {capture("file-picker-960");int item=-1;for(int n=0;n<f->picker()->rows().size();++n)if(f->picker()->rows()[n].toMap()["title"]=="otp.bin")item=n;check(item>=0,"Picker shows selected file");f->picker()->activate(item,"list");shell.dispatch(trainer::Action::Confirm);check(f->busy(),"Controller confirms background import");f->close();check(shell.service()=="settings","Can leave during import");break;}
        case 4: check(QFileInfo(dir->path()+"/bin/user/sysdata/otp.bin").size()==256,"Imported to actual portable data root");check(QFileInfo(dir->path()+"/input/otp.bin").size()==256,"Selected original kept");check(!f->tasks().isEmpty()&&f->tasks()[0].toMap()["state"]=="done","Common background task completed");emit shell.settings()->gamePreparationRequested();break;
        case 5: {bool found=false;for(const auto& row:f->fileRows())if(row.toMap()["filename"]=="sysdata/otp.bin")found=row.toMap()["checked"].toBool();check(found,"Requirement refreshed after background import");capture("file-installed-960");f->choosePack();f->picker()->navigate(dir->path()+"/input");break;}
        case 6: {int item=-1;for(int n=0;n<f->picker()->rows().size();++n)if(f->picker()->rows()[n].toMap()["title"]=="pack.zip")item=n;check(item>=0,"BIOS pack selectable");f->picker()->activate(item,"list");shell.dispatch(trainer::Action::Confirm);break;}
        case 7: check(f->report().contains("2 installed"),"Pack fills remaining console files");f->selectGroup("n3ds");capture("pack-installed-960");f->onlineAction(0);break;
        case 8: check(shell.service()=="game-preparation","Online control stays in the same screen");check(shell.settings()->onlineControls()[1].toMap()["detail"]=="pretendo","Inline Online service selector works");capture("online-inline-960");window->resize(1280,720);shell.settings()->cycleTheme(1);break;
        case 9: capture("online-inline-dark-1280");shell.dispatch(trainer::Action::Back);check(shell.service()=="settings","Controller Back returns to Settings");break;
        default: {
            timer->stop();completed=true;const bool ok=diagnostics.isEmpty()&&warnings==0;
            QFile report(output+"/verification.txt");if(report.open(QIODevice::WriteOnly))report.write(((ok?QString("PASSED\n"):QString("FAILED\n"))+diagnostics.join('\n')+QString("\nQML warnings: %1\n").arg(warnings)).toUtf8());
            QCoreApplication::exit(ok?0:1);break;
        }
        }
    });timer->start();
}
