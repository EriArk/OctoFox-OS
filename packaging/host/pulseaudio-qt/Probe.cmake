add_executable(traineros-pulse-shutdown-probe ${CMAKE_CURRENT_LIST_DIR}/ShutdownProbe.cpp)
target_include_directories(traineros-pulse-shutdown-probe PRIVATE ${CMAKE_SOURCE_DIR}/src ${CMAKE_BINARY_DIR}/src)
target_link_libraries(traineros-pulse-shutdown-probe PRIVATE KF6PulseAudioQt Qt6::Gui Qt6::Qml Qt6::Quick)
