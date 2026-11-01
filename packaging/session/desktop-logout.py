#!/usr/bin/python3 -I
"""Unprivileged KDE logout. Never activate a desktop in another session."""
import os
import subprocess
import sys


def logout(bus, request):
    # KDE Shutdown alone is activatable even in TrainerOS. Require the actual
    # compositor and session manager before invoking it.
    if not all(bus.name_has_owner(name) for name in ('org.kde.KWin', 'org.kde.ksmserver')):
        return 10
    if subprocess.call(['/usr/bin/systemctl', '--user', 'is-active', '--quiet',
                        'plasma-kwin_wayland.service']) != 0:
        return 10
    request()
    return 0


def main():
    if os.geteuid() == 0:
        return 2
    import dbus
    try:
        bus = dbus.SessionBus()
        return logout(bus, lambda: dbus.Interface(
            bus.get_object('org.kde.Shutdown', '/Shutdown'), 'org.kde.Shutdown').logout(timeout=10))
    except dbus.DBusException as error:
        print('TrainerOS: desktop logout failed: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
