#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source/object/container directories must live on the build volume (microSD on Armada).
# Usage: build.sh ODAMEX_SOURCE BUILD_DIR
# Dependencies: C/C++ toolchain, CMake/Ninja, SDL2/mixer, curl, PNG, zlib/zstd,
# X11 development libraries; pinned upstream submodules provide other libraries.
set -eu
test "$(git -C "$1" rev-parse HEAD)" = 3a763534ac609aee8d22351baa3155809c4ea355
test -z "$(git -C "$1" status --porcelain --untracked-files=no)"
test -z "$(git -C "$1" submodule status --recursive | sed -n '/^[+-U]/p')"
cmake -S "$1" -B "$2" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_LAUNCHER=OFF -DBUILD_TESTS=OFF -DBUILD_OR_FAIL=ON \
    -DUSE_LTO=OFF -DUSE_MINIUPNP=OFF -DENABLE_PORTMIDI=OFF
cmake --build "$2" -j3
