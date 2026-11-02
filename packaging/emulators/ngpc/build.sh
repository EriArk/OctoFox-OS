#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source, build and output on microSD on Armada. SDL2/SDL2_ttf development packages required.
set -eu
src=$1
build=$2
out=$3
transport=$4
recipe=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test "$(git -C "$src" rev-parse HEAD)" = d0acb0874cc07735d7fa978539bb2471b2c1e71a
test -z "$(git -C "$src" status --porcelain --untracked-files=no)"
cmake -S "$src/libretro" -B "$build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$build" -j2
mkdir -p "$out/lib"
cp "$build/ngpcraft_libretro.so" "$out/core.so"
c++ -std=c++17 -O2 -shared -fPIC "$recipe/frontend.cpp" -o "$out/frontend.so" $(pkg-config --cflags --libs sdl2 SDL2_ttf)
cp "$recipe/launch.py" "$recipe/channel.py" "$recipe/state.py" "$out/"
cp "$src/hle_bios/bios_hle.bin" "$out/bios_hle.bin"
cp "$src/LICENSE" "$out/NGPCRAFT-LICENSE"
cp "$transport" "$out/stream_transport"
python3 - "$src" "$out" <<'PY'
from pathlib import Path
import sys,zipfile
src,out=map(Path,sys.argv[1:])
with zipfile.ZipFile(out/'upstream.zip','w',zipfile.ZIP_DEFLATED) as z:
 for name in ('__init__','native','bios_fingerprint','link','link_debug','netlog','netplay','flash_file'):
  z.write(src/'core'/(name+'.py'),'core/'+name+'.py')
PY
# Armada/Fedora build. SDL2 and its display/audio drivers belong to the host;
# only the additional SDL_ttf library is bundled. ldd must resolve on each host.
cp -L /usr/lib64/libSDL2_ttf-2.0.so.0 "$out/lib/"
cp /usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf "$out/font.ttf"
mkdir -p "$out/licenses"
for package in SDL2_ttf dejavu-sans-fonts; do
    rpm -q "$package" >> "$out/licenses/packages.txt"
    rpm -ql "$package" | while IFS= read -r file; do
        case "$file" in /usr/share/licenses/*)
            if test -f "$file"; then cp "$file" "$out/licenses/$package-$(basename "$file")"; fi;;
        esac
    done
done
LD_LIBRARY_PATH="$out/lib" ldd "$out/frontend.so" > "$out/licenses/dependencies.txt"
if grep -q 'not found' "$out/licenses/dependencies.txt"; then exit 1; fi
python3 "$recipe/bundle.py" "$out"
