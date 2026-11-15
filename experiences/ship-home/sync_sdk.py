#!/usr/bin/env python3
"""Versioned local SDK code only; avatar assets remain owned by the host."""
# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent
source=root.parents[1]/'sdk/godot'
dest=root/'addons/avatar';dest.mkdir(parents=True,exist_ok=True)
files=['avatar_client.gd','avatar_presenter.gd','avatar_locomotion.gd']
shutil.copytree(source/'animations',dest/'animations',dirs_exist_ok=True)
for name in files:shutil.copy2(source/name,dest/name)
print(json.dumps({name:hashlib.sha256((dest/name).read_bytes()).hexdigest() for name in files},indent=2))
