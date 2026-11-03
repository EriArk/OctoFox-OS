# SPDX-License-Identifier: GPL-3.0-or-later
"""Private runtime namespace. Never infer targets from the user's emulators."""
from pathlib import Path

LAYOUT = 'private-home-v1'


def paths(root):
    root = Path(root).absolute()
    home = root / 'runtime-home'
    data = home / '.local/share'
    # An alias must not redirect owned runtime writes into EmuDeck/user data.
    for target in (home, data, data/'flatpak', home/'.var/app', home/'Applications'):
        for part in (target, *target.parents):
            if part == root: break
            if part.is_symlink(): raise ValueError('Linked private runtime directory: '+str(part))
    return home, data


def environment(home, base):
    home = Path(home)
    return dict(base, HOME=str(home), XDG_DATA_HOME=str(home/'.local/share'),
                XDG_CONFIG_HOME=str(home/'.config'), XDG_CACHE_HOME=str(home/'.cache'),
                XDG_STATE_HOME=str(home/'.local/state'),
                FLATPAK_USER_DIR=str(home/'.local/share/flatpak'))
