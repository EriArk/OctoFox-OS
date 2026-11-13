#pragma once
#include "core/navigation/ShellController.h"
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QTimer>
#include <memory>
#ifdef __GLIBC__
#include <malloc.h>
#endif

// Opt-in measurement of the real shell after disposable first-run setup.
// A controlled child stands in for a game; no ROM or installed emulator is used.
inline void startResourceSmoke(QQuickWindow* window, trainer::ShellController& shell,
                               const QString& directory, int& warnings) {
    struct State {
        QTemporaryDir files;
        QElapsedTimer elapsed, returning;
        QJsonArray samples;
        QJsonObject navigation;
        QString owner;
        int stage=0, cycles=0, warnings=0;
        qint64 firstFrame=-1;
        bool failed=false;
    };
    auto state=std::make_shared<State>();state->elapsed.start();state->warnings=warnings;
    auto* child=new QProcess(window);
    auto* overlay=new QQuickWindow(window);overlay->resize(320,180);overlay->setColor(Qt::darkCyan);
    overlay->setTitle("Resource test overlay");
    auto* timer=new QTimer(window);timer->setInterval(6000);
    QObject::connect(child,&QProcess::started,window,[window]{window->hide();});
    QObject::connect(child,&QProcess::finished,window,[window,state](int code,QProcess::ExitStatus status){
        state->failed|=code!=0||status!=QProcess::NormalExit;
        state->returning.start();state->firstFrame=-1;window->show();window->requestActivate();
    });
    QObject::connect(window,&QQuickWindow::frameSwapped,window,[state]{
        if(state->returning.isValid()&&state->firstFrame<0)state->firstFrame=state->returning.elapsed();
    });
    shell.openProfile();state->navigation=shell.navigationState();state->owner=shell.trainer()->profile()["id"].toString();
    QObject::connect(timer,&QTimer::timeout,window,[=,&shell,&warnings] {
        const auto sample=[&](const QString& phase) {
            QJsonObject row{{"phase",phase},{"cycle",state->cycles},{"elapsedMs",state->elapsed.elapsed()},
                            {"windowVisible",window->isVisible()},{"returnFrameMs",state->firstFrame}};
#ifdef __GLIBC__
            const auto heap=mallinfo2();
            row["allocatedHeapKiB"]=qint64(heap.uordblks/1024);
            row["unusedHeapKiB"]=qint64(heap.fordblks/1024);
            row["mappedHeapKiB"]=qint64(heap.hblkhd/1024);
#endif
            row["avatarPreviewPresent"]=window->findChild<QObject*>("avatar-preview")!=nullptr;
            QFile memory("/proc/self/smaps_rollup");
            if(memory.open(QIODevice::ReadOnly))for(const auto& line:memory.readAll().split('\n')) {
                const auto fields=line.simplified().split(' ');
                if(fields.size()>1&&(fields[0]=="Rss:"||fields[0]=="Pss:"||fields[0]=="Private_Dirty:"))
                    row[QString::fromLatin1(fields[0].chopped(1))+"KiB"]=fields[1].toLongLong();
            }
            QFile cpu("/proc/self/stat");if(cpu.open(QIODevice::ReadOnly)) {
                const auto raw=cpu.readAll();const auto fields=raw.mid(raw.lastIndexOf(')')+2).split(' ');
                if(fields.size()>12)row["cpuTicks"]=fields[11].toLongLong()+fields[12].toLongLong();
            }
            state->samples.append(row);
        };
        if(state->stage==0) {
            sample("foreground");state->stage=1;
            child->start(QDir(QCoreApplication::applicationDirPath()).filePath("trainer_process_probe"),
                         {"controlled",state->files.filePath("command"),state->files.filePath("pid")});
        } else if(state->stage==1) {
            state->failed|=child->state()!=QProcess::Running||window->isVisible();sample("game");
            overlay->show();overlay->requestActivate();state->stage=2;
        } else if(state->stage==2) {
            state->failed|=window->isVisible()||overlay->grabWindow().isNull();sample("game-overlay");overlay->hide();
            QFile command(state->files.filePath("command"));
            if(command.open(QIODevice::WriteOnly))command.write("exit");else state->failed=true;
            state->stage=3;
        } else {
            state->failed|=child->state()!=QProcess::NotRunning||!window->isVisible()||window->grabWindow().isNull()
                ||shell.navigationState()!=state->navigation||shell.trainer()->profile()["id"].toString()!=state->owner
                ||warnings!=state->warnings;
            sample("returned");
            window->grabWindow().save(directory+"/resource-return.png");
            if(++state->cycles<3){QFile::remove(state->files.filePath("command"));state->stage=0;return;}
            timer->stop();
            QFile report(directory+"/resources.json");
            if(report.open(QIODevice::WriteOnly))report.write(QJsonDocument(QJsonObject{
                {"passed",!state->failed},{"samples",state->samples},{"note","Native x86_64 shell, software graphics, controlled child; not handheld gameplay"}}).toJson());
            QCoreApplication::exit(state->failed?1:0);
        }
    });
    timer->start();
}
