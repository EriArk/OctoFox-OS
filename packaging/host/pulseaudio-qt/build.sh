#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Run in a native aarch64 Qt 6 build environment. Output/build storage belongs on SD.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
build_root=${1:?Pass a new build directory on SD}
test ! -e "$build_root"
mkdir -p -- "$build_root"
build_root=$(cd -- "$build_root" && pwd)
git clone https://invent.kde.org/libraries/pulseaudio-qt.git "$build_root/source"
git -C "$build_root/source" checkout --detach 10786fe31e640858f4f5db5366aed9c56d77bfab
git -C "$build_root/source" apply --check "$source_dir/shutdown.patch"
git -C "$build_root/source" apply "$source_dir/shutdown.patch"
git clone https://invent.kde.org/frameworks/extra-cmake-modules.git "$build_root/ecm"
git -C "$build_root/ecm" checkout --detach d8d80bcc61341239519392eef1360c796bf25931
cmake -S "$build_root/ecm" -B "$build_root/ecm-build" -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$build_root/ecm-prefix"
cmake --install "$build_root/ecm-build"
printf '\ninclude("%s/Probe.cmake")\n' "$source_dir" >> "$build_root/source/CMakeLists.txt"
cmake -S "$build_root/source" -B "$build_root/build" -DECM_DIR="$build_root/ecm-prefix/share/ECM/cmake" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=ON
cmake --build "$build_root/build" -j3
QT_QPA_PLATFORM=offscreen ctest --test-dir "$build_root/build" --output-on-failure
printf 'Artifact: %s/build/bin/libKF6PulseAudioQt.so.1.8.1\n' "$build_root"
