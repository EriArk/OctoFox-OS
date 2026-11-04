cmake_minimum_required(VERSION 3.24)
project(HomeCompanionPreview LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Quick3D Test Concurrent)
find_package(OpenSSL 3 REQUIRED COMPONENTS Crypto)
get_filename_component(ROOT ../.. ABSOLUTE)
qt_add_executable(companion-preview main.cpp
    ${ROOT}/sdk/qt/AvatarScene.cpp
    ${ROOT}/src/features/home/HomeCompanion.cpp
    ${ROOT}/src/features/trainer/AvatarAssets.cpp
    ${ROOT}/src/features/trainer/AvatarWearables.cpp)
target_include_directories(companion-preview PRIVATE ${ROOT}/src ${ROOT}/sdk/qt)
target_link_libraries(companion-preview PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Quick3D Qt6::Test Qt6::Concurrent OpenSSL::Crypto)
target_compile_definitions(companion-preview PRIVATE SOURCE_ROOT="${ROOT}" TRAINER_AVATAR_SOURCE_PACK="${ROOT}/assets/avatar/packs/trainer-avatar-1")
file(GLOB_RECURSE props CONFIGURE_DEPENDS ${ROOT}/assets/home-pet/*.glb ${ROOT}/assets/home-pet/backgrounds/*.png ${ROOT}/assets/home-pet/ui/*.svg)
qt_add_resources(companion-preview props PREFIX "/home-pet" BASE ${ROOT}/assets/home-pet FILES ${props})
qt_add_resources(companion-preview fonts PREFIX "/fonts" BASE ${ROOT}/assets/fonts
    FILES ${ROOT}/assets/fonts/Bungee-Regular.ttf ${ROOT}/assets/fonts/ChakraPetch-Bold.ttf ${ROOT}/assets/fonts/Fredoka.ttf)
