#!/usr/bin/python3 -I
"""Carry physical panel brightness into KWin before it restores old settings.

Runs as the desktop user, once before the standalone compositor. Never writes
sysfs, output geometry, external-monitor settings or automatic/HDR brightness.
"""
import json
import os
from pathlib import Path
import stat
import tempfile


def panel_value(backlights, drm):
    lights = list(Path(backlights).iterdir())
    panels = [p for p in Path(drm).glob('card*-*')
              if p.name.split('-', 1)[1].startswith(('DSI-', 'eDP-', 'LVDS-'))
              and (p / 'status').is_file() and (p / 'status').read_text().strip() == 'connected']
    if len(lights) != 1 or len(panels) != 1:
        return None
    maximum = int((lights[0] / 'max_brightness').read_text())
    current = int((lights[0] / 'brightness').read_text())
    if maximum <= 1 or not 1 <= current <= maximum:
        return None  # A blanked/off panel is not a new user preference.
    # KWin externalbrightness_v1 maps internal panels from [1, max] to [0, 1].
    return panels[0].name.split('-', 1)[1], (current - 1) / (maximum - 1)


def sync(path, panel):
    path = Path(path)
    if panel is None or path.is_symlink() or not path.is_file():
        return False
    before = path.read_bytes()
    value = json.loads(before)
    if not isinstance(value, list):
        return False
    groups = [g for g in value if isinstance(g, dict) and g.get('name') == 'outputs']
    if len(groups) != 1 or not isinstance(groups[0].get('data'), list):
        return False
    matches = [o for o in groups[0]['data'] if isinstance(o, dict) and o.get('connectorName') == panel[0]]
    if len(matches) != 1:
        return False
    output = matches[0]
    if output.get('automaticBrightness') or output.get('highDynamicRange'):
        return False
    if output.get('brightness') == panel[1]:
        return False
    output['brightness'] = panel[1]
    # Preserve the pre-integration configuration once, without following links.
    backup = path.with_name(path.name + '.before-traineros-brightness')
    try:
        with backup.open('xb') as stream:
            stream.write(before)
        backup.chmod(stat.S_IMODE(path.stat().st_mode))
    except FileExistsError:
        pass
    fd, temporary = tempfile.mkstemp(prefix='.traineros-brightness-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, indent=4, ensure_ascii=False)
            stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), stat.S_IMODE(path.stat().st_mode))
        if path.is_symlink() or path.read_bytes() != before:
            return False  # Do not replace a concurrent user/configuration edit.
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print('TrainerOS: preserved panel brightness for ' + panel[0])
    return True


if __name__ == '__main__':
    if os.geteuid() == 0:
        raise SystemExit(2)
    try:
        config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
        sync(config / 'kwinoutputconfig.json', panel_value('/sys/class/backlight', '/sys/class/drm'))
    except (OSError, ValueError, TypeError) as error:
        # An unfamiliar host must still reach its desktop.
        print('TrainerOS: brightness handoff skipped: ' + str(error))
