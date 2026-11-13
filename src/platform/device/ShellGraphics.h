#pragma once

#include <QFile>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QDebug>
#include <QQmlEngine>
#include <QTimer>
#ifdef __GLIBC__
#include <malloc.h>
#endif

namespace trainer {

// Keep the shell/session alive for Home, saves and multiplayer. Release only
// each hidden window's render resources. A visible game overlay is independent
// of the hidden main window and retains its own live scene graph.
inline void releaseHiddenShellGraphics(QQuickWindow* window, QQmlEngine* engine)
{
#ifdef __GLIBC__
    // Qt releases graphics on its render thread. Once that has completed, return
    // freed allocator pages to Linux rather than retaining the old peak RSS.
    QObject::connect(window, &QQuickWindow::sceneGraphInvalidated, window, [window] {
        QTimer::singleShot(250, window, [window] {
            if (!window->isVisible()) malloc_trim(0);
        });
    }, Qt::QueuedConnection);
#endif
    auto* release = new QTimer(window);
    release->setSingleShot(true);
    release->setInterval(1000); // Avoid rebuilding on a brief hide/show handoff.
    QObject::connect(window, &QWindow::visibleChanged, release, [window, release](bool visible) {
        if (visible) {
            release->stop();
            window->setPersistentGraphics(true);
            window->setPersistentSceneGraph(true);
        } else release->start();
    });
    QObject::connect(release, &QTimer::timeout, window, [window, engine] {
        if (window->isVisible()) return;
        window->setPersistentSceneGraph(false);
        window->setPersistentGraphics(false);
        window->releaseResources();
        // Hidden preview Loaders have already released their instances. Keep
        // all live QML objects, browser profiles and controller state intact.
        engine->collectGarbage();
        engine->trimComponentCache();
    });
}

inline void configureShellGraphics()
{
#ifdef Q_OS_LINUX
    // Odin's current Armada/Freedreno OpenGL path has repeatedly left the
    // QSGRenderThread in an unrecoverable GPU wait. Use Qt's Vulkan renderer
    // for the shell only; never export a backend choice to emulator children.
    // An explicit Qt backend remains the maintenance/rollback override.
    if (qEnvironmentVariableIsSet("QSG_RHI_BACKEND")
        || qEnvironmentVariableIsSet("QT_QUICK_BACKEND")
        || qEnvironmentVariableIsSet("QMLSCENE_DEVICE"))
        return;
    const auto platform = QGuiApplication::platformName();
    if (platform != QStringLiteral("xcb") && !platform.startsWith(QStringLiteral("wayland")))
        return;
    QFile model(QStringLiteral("/proc/device-tree/model"));
    if (!model.open(QIODevice::ReadOnly))
        return;
    auto name = model.readAll();
    while (name.endsWith('\0')) name.chop(1);
#if QT_VERSION >= QT_VERSION_CHECK(6, 7, 0)
    if (name.trimmed() == "Retroid Pocket Flip2") {
        // The installed Flip OpenGL route corrupts previously cached text
        // after profile/menu glyphs grow the atlas. Curve text bypasses that
        // distance-field atlas without changing emulator or shell backends.
        QQuickWindow::setTextRenderType(QQuickWindow::CurveTextRendering);
        qInfo() << "OctoFox OS shell text: curve rendering (Flip 2 glyph cache workaround)";
#ifdef TRAINER_WEBENGINE
        // Chromium's composited page tiles are corrupted on this device's
        // Armada OpenGL route too. The actual normal/fullscreen browser and
        // chassis were checked with Vulkan. Keep the override local to this
        // shell; explicit Qt backend choices above still take precedence.
        QQuickWindow::setGraphicsApi(QSGRendererInterface::Vulkan);
        qInfo() << "OctoFox OS shell graphics: Vulkan (Flip 2 browser composition)";
#endif
        return;
    }
#endif
    if (name.trimmed() != "AYN Odin 2")
        return;
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Vulkan);
    qInfo() << "OctoFox OS shell graphics: Vulkan (Odin 2 workaround)";
#endif
}

} // namespace trainer
