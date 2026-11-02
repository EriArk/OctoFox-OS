#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
# On Armada, SOURCE and OUT must be on the microSD. Never build on internal storage.
source_dir=$1
output_dir=$2
recipe_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test "$(git -C "$source_dir" rev-parse HEAD)" = b1e04c738cb48a1dae0574b8877f6a116d270ca1
test -z "$(git -C "$source_dir" status --porcelain)"
git -C "$source_dir" apply --check "$recipe_dir/0001-canonical-netplay-state.patch"
git -C "$source_dir" apply "$recipe_dir/0001-canonical-netplay-state.patch"
make -C "$source_dir" -j2 platform=unix
python3 "$recipe_dir/check-state.py" "$source_dir/neocd_libretro.so"
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
cp "$source_dir/neocd_libretro.so" "$output_dir/core.so"
cp "$source_dir/LICENSE.md" "$output_dir/LICENSE.md"
# Keep all third-party notices and the corresponding patched source. In
# particular, the legacy Z80 notice is not replaced by the top-level LGPL.
git -C "$source_dir" ls-files -z | tar -C "$source_dir" --null -T - -cJf "$output_dir/source.tar.xz"
cp "$recipe_dir/0001-canonical-netplay-state.patch" "$output_dir/"
python3 "$recipe_dir/bundle.py" "$output_dir"
