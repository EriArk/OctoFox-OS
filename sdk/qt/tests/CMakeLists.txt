cmake_minimum_required(VERSION 3.24)
project(AvatarCardsChecks LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Test Network Quick Quick3D Concurrent)
find_package(OpenSSL 3 REQUIRED COMPONENTS Crypto)
add_executable(avatar-cards-tests AvatarCardsTests.cpp ../AvatarCards.h)
target_link_libraries(avatar-cards-tests PRIVATE Qt6::Test Qt6::Network OpenSSL::Crypto)
enable_testing()
add_test(NAME avatar_cards COMMAND avatar-cards-tests)
add_executable(avatar-portrait-preview PortraitPreview.cpp)
target_include_directories(avatar-portrait-preview PRIVATE ..)
target_link_libraries(avatar-portrait-preview PRIVATE Qt6::Quick Qt6::Quick3D Qt6::Concurrent OpenSSL::Crypto)
target_compile_definitions(avatar-portrait-preview PRIVATE PORTRAIT_QML="${CMAKE_CURRENT_SOURCE_DIR}/../")

set_source_files_properties(../AvatarView3D.qml PROPERTIES QT_RESOURCE_ALIAS AvatarView3D.qml)
qt_add_qml_module(avatar-portrait-preview URI TrainerOS VERSION 1.0 NO_CACHEGEN
    SOURCES ../AvatarScene.h ../AvatarScene.cpp
    QML_FILES ../AvatarView3D.qml)
