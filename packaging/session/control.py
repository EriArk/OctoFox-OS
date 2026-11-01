#!/usr/bin/python3 -I
"""Root-owned, fixed-verb Armada session boundary. Never load user Python code."""
import os
import json
import pwd
from pathlib import Path
import subprocess
import sys
import tempfile
import time

OVERRIDE = Path("/etc/sddm.conf.d/zz-steamos-autologin.conf")
ARMADA = "/usr/libexec/armada/session-control"
MARKER = Path("/run/traineros-transition")


def logout_desktop(uid):
    """Ask the caller's real KDE session to finish before releasing its seat.

    10 means no live standalone KDE session; only that result permits the
    display-manager fallback. A rejected logout must not force-close documents.
    """
    if not uid or not uid.isascii() or not uid.isdigit() or int(uid) == 0:
        return 10
    try:
        user = pwd.getpwuid(int(uid)).pw_name
    except KeyError:
        return 10
    try:
        return subprocess.call(['/usr/sbin/runuser', '-u', user, '--', '/usr/bin/env',
                                'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/' + uid + '/bus',
                                'XDG_RUNTIME_DIR=/run/user/' + uid,
                                '/usr/bin/python3', '-I', '/var/opt/traineros/session/desktop-logout.py'], timeout=15)
    except subprocess.TimeoutExpired:
        return 1


def session_pids():
    result = []
    for process in Path("/proc").glob("[0-9]*"):
        try:
            arguments = (process / "cmdline").read_bytes().split(b"\0")
            if arguments[:2] == [b"/bin/bash", b"/var/opt/traineros/session/start-session.sh"]:
                result.append(int(process.name))
        except OSError:
            pass
    return result


def consume_transition(pid):
    try:
        value = json.loads(MARKER.read_text())
        if time.monotonic() - value["time"] > 30 or pid not in value["pids"]:
            return False
        value["pids"].remove(pid)
        atomic_write(MARKER, json.dumps(value))
        return True
    except (OSError, ValueError, KeyError, TypeError):
        return False


def atomic_write(path, content):
    fd, temporary = tempfile.mkstemp(prefix=".traineros-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), 0o644)
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    if os.geteuid() != 0 or len(sys.argv) not in {2, 3}:
        return 2
    action = sys.argv[1]
    if action not in {"traineros", "default-traineros", "desktop", "steam", "recover", "reboot", "poweroff"}:
        return 2
    if (action == "recover" and (len(sys.argv) != 3 or not sys.argv[2].isascii() or not sys.argv[2].isdigit())) or (action != "recover" and len(sys.argv) != 2):
        return 2
    caller_uid = os.environ.get('SUDO_UID', '')
    os.environ.clear()
    os.environ.update(PATH="/usr/sbin:/usr/bin:/sbin:/bin", LANG="C.UTF-8")
    if action == "recover":
        # Only the old session may consume its own transition. A new session's
        # startup failure must still recover, including after a manual switch.
        if consume_transition(int(sys.argv[2])):
            return 0
        if OVERRIDE.is_file() and "Session=traineros.desktop" not in OVERRIDE.read_text():
            return 0
        return subprocess.call([ARMADA, "switch-desktop"])
    if action in {"traineros", "default-traineros"}:
        if not Path("/etc/traineros/wayland-sessions/traineros.desktop").is_file():
            return 3
        atomic_write(OVERRIDE, "[Autologin]\nSession=traineros.desktop\n")
        if action == "default-traineros":
            return 0
        result = logout_desktop(caller_uid)
        if result != 10:
            return result
    atomic_write(MARKER, json.dumps({"pids": session_pids(), "time": time.monotonic()}))
    if action in {"desktop", "steam"}:
        # Armada's switch-gamemode tries KDE logout first. D-Bus can activate
        # org.kde.Shutdown even in TrainerOS and report success without ending
        # this session. Let Armada choose the destination, then end the actual
        # SDDM session explicitly; never depend on a different desktop's logout.
        result = subprocess.call([ARMADA, "default-desktop" if action == "desktop" else "default-gamemode"])
        if result == 0:
            result = subprocess.call(["/usr/bin/systemctl", "--no-block", "restart", "sddm"])
    else:
        result = subprocess.call(["/usr/bin/systemctl", "--no-block", "restart", "sddm"] if action == "traineros"
                                 else ["/usr/bin/systemctl", "--no-block", action])
    if result and MARKER.exists():
        MARKER.unlink()
    return result


if __name__ == "__main__":
    sys.exit(main())
