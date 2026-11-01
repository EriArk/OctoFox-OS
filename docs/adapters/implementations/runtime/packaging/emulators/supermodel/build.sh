#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Requires C++17, SDL2/SDL2_net, OpenGL/GLU, zlib, Qt6 Core/Network and cmake.
# Usage: build.sh PINNED_UPSTREAM EMPTY_OUTPUT REVIEWED_STREAM_TRANSPORT
set -eu
source=$(realpath "$1")
out=$(realpath -m "$2")
transport=$(realpath "$3")
recipe=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(realpath "$recipe/../../..")
revision=036af1c8d6640c5a60709c1f99144635ed82a184
test "$(git -C "$source" rev-parse HEAD)" = "$revision"
test ! -e "$out"
mkdir -p "$out/upstream" "$out/package/bin" "$out/package/lib" "$out/package/Config"
git -C "$source" archive "$revision" | tar -x -C "$out/upstream"
cd "$out/upstream"
patch -p1 --dry-run < "$recipe/native-inspect.patch"
patch -p1 < "$recipe/native-inspect.patch"
make -f Makefiles/Makefile.UNIX -j2
cmake -S "$repo/tools/model3-link" -B "$out/endpoint" -DCMAKE_BUILD_TYPE=Release
cmake --build "$out/endpoint" -j2
cp bin/supermodel "$out/package/bin/supermodel.real"
cp Config/Games.xml "$out/package/Config/"
cp "$recipe/Supermodel.ini" "$out/package/Config/"
cp "$recipe/launch.sh" "$out/package/bin/supermodel"
cp "$recipe/content.py" "$out/package/"
cp "$out/endpoint/model3_endpoint" "$out/package/"
cp "$transport" "$out/package/stream_transport"
for lib in libSDL2_net-2.0.so.0 libGLU.so.1; do
    path=$(ldd bin/supermodel | awk -v lib="$lib" '$1 == lib && $2 == "=>" { print $3 }')
    test -f "$path"
    cp -L "$path" "$out/package/lib/$lib"
done
chmod 755 "$out/package/bin/supermodel" "$out/package/bin/supermodel.real" "$out/package/model3_endpoint" "$out/package/stream_transport"
cp Docs/LICENSE.txt "$out/package/SUPERMODEL-LICENSE.txt"
cp "$recipe/GLU-NOTICES.txt" "$out/package/"
test -f /usr/share/licenses/SDL2_net/LICENSE.txt
cp /usr/share/licenses/SDL2_net/LICENSE.txt "$out/package/SDL2-NET-LICENSE.txt"
printf '%s\n' "Built $out/package; seal with bundle.py using the owner's actual config and NVRAM paths."
