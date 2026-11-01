// SPDX-License-Identifier: GPL-3.0-or-later
// Run against a real PulseAudio/PipeWire server; never changes volume or plays audio.
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTimer>
#include <QDebug>
#include <memory>
#include "context.h"
#include "sink.h"
#include "port.h"

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    // Reproduce a QML consumer retained beyond the application, as in Plasma.
    static auto engine = std::make_unique<QQmlEngine>();
    static std::unique_ptr<QObject> text;
    auto *context = PulseAudioQt::Context::instance();
    bool observed = false;
    bool destroyedWhileAlive = false;
    QTimer poll;
    QObject::connect(&poll, &QTimer::timeout, &app, [&] {
        if (context->sinks().isEmpty() || context->sinks().first()->ports().isEmpty())
            return;
        poll.stop();
        auto *port = context->sinks().first()->ports().first();
        engine->rootContext()->setContextProperty(QStringLiteral("audioPort"), port);
        QQmlComponent component(engine.get());
        component.setData("import QtQuick; Text { text: audioPort ? audioPort.description : 'removed'; font.pixelSize: 16 }", QUrl());
        text.reset(component.create());
        if (!text) {
            qCritical() << component.errors();
            app.exit(2);
            return;
        }
        observed = true;
        QObject::connect(port, &QObject::destroyed, &app, [&] {
            destroyedWhileAlive = QCoreApplication::instance() && !QCoreApplication::closingDown();
        });
        QTimer::singleShot(0, &app, &QCoreApplication::quit);
    });
    poll.start(50);
    QTimer::singleShot(5000, &app, &QCoreApplication::quit);
    app.exec();
    const bool empty = context->sinks().isEmpty() && context->sources().isEmpty() && !context->isValid();
    context->reconnectDaemon(); // A late callback must not recreate audio objects.
    const bool stayedDisconnected = !context->isValid() && !context->isAutoConnecting();
    qInfo() << "observed" << observed << "destroyedWhileAlive" << destroyedWhileAlive
            << "empty" << empty << "stayedDisconnected" << stayedDisconnected;
    // Clean the deliberately retained consumer after the lifetime assertions.
    text.reset();
    engine.reset();
    return observed && destroyedWhileAlive && empty && stayedDisconnected ? 0 : 1;
}
