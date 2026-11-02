# Use the existing Fedora cross sysroot and native Qt tools; melonDS also has ASM.
include("${CMAKE_CURRENT_LIST_DIR}/../dolphin/arm64-fedora44.cmake")
set(CMAKE_ASM_COMPILER clang)
set(CMAKE_ASM_COMPILER_TARGET aarch64-redhat-linux-gnu)
set(CMAKE_ASM_FLAGS_INIT "--target=aarch64-redhat-linux-gnu --gcc-toolchain=/opt/arm64/usr")
