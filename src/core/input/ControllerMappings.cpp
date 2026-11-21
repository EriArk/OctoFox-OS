#include "ControllerMappings.h"
#include <QFile>
#include <QDebug>
#include <SDL.h>

static void registerControllerResources() { Q_INIT_RESOURCE(emulator_defaults); }

namespace trainer {
void loadPackagedControllerMappings() {
    static const bool registered=[] { registerControllerResources();return true; }();
    Q_UNUSED(registered);
#ifdef Q_OS_LINUX
    QFile database(":/emulators/gamecontrollerdb-linux.txt");
    if (!database.open(QIODevice::ReadOnly)) { qWarning() << "SDL controller database unavailable"; return; }
    const auto mappings=database.readAll();
    auto* stream=SDL_RWFromConstMem(mappings.constData(),int(mappings.size()));
    if (!stream || SDL_GameControllerAddMappingsFromRW(stream,1)<0)
        qWarning() << "Could not load SDL controller mappings:" << SDL_GetError();
#endif
}
}
