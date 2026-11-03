#include <QCoreApplication>
#include <QTimer>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <cstdlib>
#ifdef Q_OS_WIN
#include <windows.h>
#else
#include <sys/resource.h>
#endif

// An original, content-free child program, compiled only for tests.
int main(int argc, char** argv) {
#ifdef Q_OS_WIN
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
#else
    const rlimit noCore{0, 0}; setrlimit(RLIMIT_CORE, &noCore);
#endif
    QCoreApplication app(argc, argv);
    const auto args = app.arguments();
    if (args.size() == 3 && args[1] == "environment") {
        QFile file(args[2]); if (!file.open(QIODevice::WriteOnly)) return 3;
        QJsonObject result;
        for (const auto* key : {"HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "FLATPAK_USER_DIR"})
            result[key]=qEnvironmentVariable(key);
        file.write(QJsonDocument(result).toJson()); return 0;
    }
    if (args.size() == 3 && args[1] == "--psp-content") {
        QFile input(args[2]), output;
        if (!input.open(QIODevice::ReadOnly) || !output.open(stdout,QIODevice::WriteOnly)) return 3;
        output.write(input.readAll());return 0;
    }
    if (args.size() >= 3 && args[1] == "arguments") {
        QFile file(args[2]); if (!file.open(QIODevice::WriteOnly)) return 3;
        file.write(QJsonDocument(QJsonArray::fromStringList(args.mid(3))).toJson());
        return 0;
    }
    if (args.size() >= 4 && args[1] == "echo") {
        QFile file(args[2]); if (!file.open(QIODevice::WriteOnly)) return 3;
        file.write(args[3].toUtf8()); return 0;
    }
    if (args.size() == 5 && args[1] == "header" && args[2] == "-j" && args[3] == "-i") {
        QFile input(args[4]), output;
        if (!input.open(QIODevice::ReadOnly) || !output.open(stdout,QIODevice::WriteOnly)) return 3;
        output.write(input.readAll());return 0;
    }
    const auto mode = args.value(1);
    if(mode=="delayed-ready") {
        QFile output;if(!output.open(stdout,QIODevice::WriteOnly))return 3;
        QTimer::singleShot(150,&app,[&]{output.write("GAME_");output.flush();});
        QTimer::singleShot(300,&app,[&]{output.write("READY\nGAME_READY\n");output.flush();});
        QTimer::singleShot(600,&app,&QCoreApplication::quit);
        return app.exec();
    }
    if (mode == "stdin-control" && args.size() == 4) {
        QFile identity(args[3]); if (!identity.open(QIODevice::WriteOnly)) return 3;
        identity.write(QByteArray::number(QCoreApplication::applicationPid())); identity.close();
        QFile input, journal(args[2]);
        if (!input.open(stdin,QIODevice::ReadOnly)||!journal.open(QIODevice::WriteOnly))return 3;
        for(;;) {
            const auto line=input.readLine(256);if(line.isEmpty())return 4;
            journal.write(line);journal.flush();
            if(line=="QUIT\n"||line=="{\"action\":\"quit\"}\n")return 0;
        }
    }
    if (mode == "controlled" && args.size() == 4) {
        QFile identity(args[3]); if (!identity.open(QIODevice::WriteOnly)) return 3;
        identity.write(QByteArray::number(QCoreApplication::applicationPid())); identity.close();
        QTimer commands;
        QObject::connect(&commands, &QTimer::timeout, &app, [&] {
            QFile control(args[2]); if (!control.open(QIODevice::ReadOnly)) return;
            const auto command = control.readAll();
            if (command == "crash") std::abort();
            if (command == "exit") app.quit();
            if (command == "error") app.exit(7);
        });
        commands.start(10);
        QTimer::singleShot(15000, &app, [&] { app.exit(8); });
        return app.exec();
    }
    if (mode == "output") {
        QFile output; if (!output.open(stdout, QIODevice::WriteOnly)) return 3;
        output.write("original failure fixture\n"); output.flush();
        QTimer::singleShot(10000, &app, &QCoreApplication::quit);
        return app.exec();
    }
    QTimer::singleShot(mode == "wait" ? 10000 : 100, &app, [&] {
        if (mode == "crash") std::abort();
        app.exit(mode == "error" ? 7 : 0);
    });
    return app.exec();
}
