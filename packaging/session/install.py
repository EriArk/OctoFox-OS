#!/usr/bin/python3 -I
"""Install additive session files on the validated immutable ArmadaOS layout.

Run from a reviewed checkout as root. Only --default changes the boot preference.
An existing file's first version is retained in /var/lib/traineros/session-backup.
"""
import argparse
import configparser
import importlib.util
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import tempfile

BOOT_DEFAULT = '/etc/systemd/system/armada-session-default.service.d/traineros.conf'


def prepare_uninstall(owned, override, select_desktop):
    # Never leave SDDM pointing to the session whose files are about to disappear.
    # Verify everything first, including user drift, before changing any preference.
    for name in owned.data['files']: owned.check(name)
    if owned.target(BOOT_DEFAULT).exists() and BOOT_DEFAULT not in owned.data['files']:
        raise ValueError('Unmanaged boot preference requires explicit recovery before removal')
    if override.exists() and b'Session=traineros.desktop' in override.read_bytes():
        select_desktop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--user", required=True)
    parser.add_argument("--default", action="store_true", help="Boot into the validated TrainerOS session")
    parser.add_argument("--managed", action="store_true", help="Record ownership for the recoverable Software installer")
    parser.add_argument("--uninstall", action="store_true", help="Remove only unchanged managed session files")
    parser.add_argument("--plasma-audio-library", type=Path, help="Reviewed optional PulseAudioQt shutdown repair artifact")
    helpers = parser.add_mutually_exclusive_group()
    helpers.add_argument("--emulator-support-only", action="store_true", help="Update Adventure helpers without changing the session")
    helpers.add_argument("--clock-only", action="store_true", help="Install date/time permissions without changing the session")
    args = parser.parse_args()
    if args.plasma_audio_library and (args.uninstall or args.emulator_support_only or args.clock_only):
        parser.error('The Plasma repair artifact belongs to a session installation')
    if (args.managed or args.uninstall) and (args.emulator_support_only or args.clock_only) or args.uninstall and args.default:
        parser.error("Managed session operations cannot be combined with helper-only or uninstall/default options")
    if args.default and (args.emulator_support_only or args.clock_only):
        parser.error("Helper-only installation cannot change the boot default")
    if os.geteuid() != 0 or not re.fullmatch(r"[a-z_][a-z0-9_-]*", args.user):
        parser.error("Use root and an existing local login name")
    account = pwd.getpwnam(args.user)
    if account.pw_uid == 0:
        parser.error("The graphical shell must not run as root")
    owned = None
    if args.managed or args.uninstall:
        ledger_path = Path('/var/lib/traineros/managed-session.json')
        ledger_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if ledger_path.is_symlink() or any(p.is_symlink() for p in ledger_path.parents) or ledger_path.parent.stat().st_uid != 0 or ledger_path.parent.stat().st_mode & 0o022 or (ledger_path.exists() and (ledger_path.stat().st_uid != 0 or ledger_path.stat().st_mode & 0o022)):
            parser.error('Unsafe session ownership record')
        ownership_spec = importlib.util.spec_from_file_location("session_ownership", Path(__file__).with_name("ownership.py"))
        ownership_module = importlib.util.module_from_spec(ownership_spec)
        ownership_spec.loader.exec_module(ownership_module)
        owned = ownership_module.Ownership(ledger_path, args.user)
    if args.uninstall:
        if not ledger_path.exists():
            print('No managed session files were installed; other session files are preserved.')
            return
        prepare_uninstall(owned, Path('/etc/sddm.conf.d/zz-steamos-autologin.conf'),
                          lambda: subprocess.run(['/usr/libexec/armada/session-control', 'default-desktop'], check=True))
        # Drop user-owned links as that user, before removing the trusted target.
        # Older installations did not have this helper.
        entry_helper = Path('/var/opt/traineros/session/desktop-entry.py')
        for name in owned.data['files']: owned.check(name)
        if str(entry_helper) in owned.data['files'] and entry_helper.is_file():
            subprocess.run(['/usr/sbin/runuser', '-u', args.user, '--', '/usr/bin/python3', '-I',
                            str(entry_helper), 'uninstall'], check=True)
        owned.uninstall()
        subprocess.run(['/usr/bin/systemctl', 'daemon-reload'], check=True)
        print('Managed session files removed. Host defaults and personal data preserved.')
        return
    for binary in ["/usr/bin/gamescope", "/usr/libexec/armada/device-env",
                   "/usr/libexec/armada/session-control", "/usr/sbin/visudo", "/usr/sbin/runuser"]:
        if not os.access(binary, os.X_OK):
            parser.error("Missing platform prerequisite: " + binary)
    if not os.access(Path(account.pw_dir) / ".local/bin/traineros", os.X_OK):
        parser.error("Install and validate the normal TrainerOS application first")
    if args.default:
        boot_service = Path("/usr/lib/systemd/system/armada-session-default.service")
        if not boot_service.is_file() or "ExecStart=/usr/libexec/armada/session-control default-gamemode" not in boot_service.read_text():
            parser.error("Revalidate the current ArmadaOS boot session mechanism before selecting a default")
    # Preserve the currently configured search directories, not just our own.
    directories = ["/usr/local/share/wayland-sessions", "/usr/share/wayland-sessions"]
    config = configparser.ConfigParser(interpolation=None, strict=False)
    paths = sorted(Path("/etc/sddm.conf.d").glob("*.conf")) + [Path("/etc/sddm.conf")]
    for path in paths:
        if path.is_file():
            config.read(path)
    if config.has_option("Wayland", "SessionDir"):
        directories = config.get("Wayland", "SessionDir").split(",")
    directories = list(dict.fromkeys(d.strip() for d in directories if d.strip()))
    if any(not d.startswith("/") or "\n" in d for d in directories):
        parser.error("Unexpected SDDM session search path")
    own = "/etc/traineros/wayland-sessions"
    if own not in directories:
        directories.append(own)
    source = Path(__file__).resolve().parent
    audio_payload = []
    if args.plasma_audio_library:
        spec = importlib.util.spec_from_file_location('plasma_audio_repair', source.parent / 'host/pulseaudio-qt/integration.py')
        repair = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(repair)
        audio_payload = repair.files(args.plasma_audio_library)
    backup = Path("/var/lib/traineros/session-backup")
    backup.mkdir(parents=True, exist_ok=True, mode=0o700)

    planned = []
    def write_file(path, data, mode):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
        if path.parent.stat().st_uid != 0 or path.parent.stat().st_mode & 0o022:
            raise RuntimeError("Install directory must be owned and writable only by root")
        if args.managed:
            owned.preparing(str(path), data)
        prior = backup / str(path).lstrip("/").replace("/", "__")
        if not prior.exists() and not Path(str(prior) + ".absent").exists():
            if path.exists():
                shutil.copy2(path, prior)
            else:
                Path(str(prior) + ".absent").touch(mode=0o600)
        fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".traineros-")
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(data); stream.flush(); os.fchmod(stream.fileno(), mode); os.fsync(stream.fileno())
            os.replace(temporary, path)
            directory = os.open(path.parent, os.O_DIRECTORY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def install(path, data, mode):
        if args.managed: planned.append((path, data, mode))
        else: write_file(path, data, mode)

    if not args.emulator_support_only:
        # Narrow existing system-service operations to the active local device owner.
        # No root shell, arbitrary command or global wheel grant is introduced.
        rule = '''polkit.addRule(function(action, subject) {
    if (subject.local && subject.active && subject.user == "%s" &&
        ["org.freedesktop.timedate1.set-time", "org.freedesktop.timedate1.set-timezone",
         "org.freedesktop.timedate1.set-ntp"].indexOf(action.id) >= 0)
        return polkit.Result.YES;
});
''' % args.user
        install("/etc/polkit-1/rules.d/50-traineros-clock.rules", rule.encode(), 0o644)
    if args.clock_only:
        print("Date/time permissions installed. Session and clock settings preserved.")
        return

    specification = importlib.util.spec_from_file_location("emulator_support", source.parent / "integrations/emulator_support.py")
    support = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(support)
    support.install_support(account, install, activate=not args.managed)
    if args.emulator_support_only:
        print("Adventure helpers installed. Session, emulators and saves preserved.")
        return

    radio_spec = importlib.util.spec_from_file_location('traineros_install_radio', source.parent / 'integrations/install-radio-control.py')
    radio_install = importlib.util.module_from_spec(radio_spec)
    radio_spec.loader.exec_module(radio_install)
    radio_install.install(args.user, writer=install)

    helper = "/var/opt/traineros/session/control.py"
    verbs = ["traineros", "default-traineros", "desktop", "steam", "recover *", "poweroff", "reboot"]
    policy = (args.user + " ALL=(root) NOPASSWD: " + ", ".join(helper + " " + v for v in verbs) + "\n").encode()
    with tempfile.NamedTemporaryFile(prefix="traineros-sudoers-") as trial:
        trial.write(policy); trial.flush()
        subprocess.run(["/usr/sbin/visudo", "-cf", trial.name], check=True, stdout=subprocess.DEVNULL)
    for name in ["client.py", "start-session.sh", "compositor.sh", "control.py", "desktop-entry.py",
                 "desktop-logout.py", "plasma-brightness.py"]:
        install("/var/opt/traineros/session/" + name, (source / name).read_bytes().replace(b"\r\n", b"\n"), 0o755)
    install(own + "/traineros.desktop", (source / "traineros.desktop").read_bytes(), 0o644)
    # /usr/local is also immutable on Armada. Keep the target with our helpers
    # and create the XDG application link without root privileges below.
    install("/var/opt/traineros/session/org.traineros.Session.desktop",
            (source / "org.traineros.Session.desktop").read_bytes().replace(b"\r\n", b"\n"), 0o644)
    install("/etc/systemd/user/traineros-session.service", (source / "traineros-session.service").read_bytes(), 0o644)
    install("/etc/systemd/user/plasma-kwin_wayland.service.d/50-traineros-brightness.conf",
            (source / "plasma-brightness.conf").read_bytes().replace(b"\r\n", b"\n"), 0o644)
    for path, data, mode in audio_payload:
        install(path, data, mode)
    install("/etc/sudoers.d/traineros-session", policy, 0o440)
    power_spec = importlib.util.spec_from_file_location("traineros_install_power", source.parent / "integrations/install-power.py")
    power_install = importlib.util.module_from_spec(power_spec)
    power_spec.loader.exec_module(power_install)
    power_install.install(args.user, writer=install if args.managed else None, configure_sleep=not args.managed)
    install("/etc/sddm.conf.d/90-traineros.conf",
            ("[Wayland]\nSessionDir=" + ",".join(directories) + "\n").encode(), 0o644)
    if args.default:
        install("/etc/systemd/system/armada-session-default.service.d/traineros.conf",
                (source / "armada-session-default.conf").read_bytes(), 0o644)
    if args.managed:
        # Validate every destination before writing the first file. Recovery may
        # resume an interrupted journal, but must never adopt an old manual install.
        for path, _, _ in planned: owned.check(path)
        for path, data, mode in planned: write_file(path, data, mode)
        subprocess.run(['/usr/bin/systemctl', 'daemon-reload'], check=True)
    subprocess.run(['/usr/sbin/runuser', '-u', args.user, '--', '/usr/bin/python3', '-I',
                    '/var/opt/traineros/session/desktop-entry.py', 'install'], check=True)
    runtime = '/run/user/' + str(account.pw_uid)
    if Path(runtime, 'bus').exists():
        subprocess.run(['/usr/sbin/runuser', '-u', args.user, '--', '/usr/bin/env',
                        'XDG_RUNTIME_DIR=' + runtime, 'DBUS_SESSION_BUS_ADDRESS=unix:path=' + runtime + '/bus',
                        '/usr/bin/systemctl', '--user', 'daemon-reload'], check=True)
    # Keep the original default for an explicit rollback, without modifying it.
    original = backup / "original-autologin.conf"
    override = Path("/etc/sddm.conf.d/zz-steamos-autologin.conf")
    if not original.exists() and override.is_file():
        shutil.copy2(override, original)
    if args.default:
        subprocess.run(["/usr/bin/systemctl", "daemon-reload"], check=True)
        subprocess.run([helper, "default-traineros"], check=True)
        print("TrainerOS is the boot default. Steam and Desktop choices remain available.")
    else:
        print("TrainerOS session choice installed. Current autologin is unchanged.")


if __name__ == "__main__":
    main()
