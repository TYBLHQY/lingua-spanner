cmake_minimum_required(VERSION 3.16)
project(lingua-spanner VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}" CACHE PATH "Install prefix")

# ── Qt6 QML module (ProcessHelper — no KF6 needed) ─────────
find_package(Qt6 6.7 REQUIRED COMPONENTS Core Qml)

qt_policy(SET QTP0001 NEW)

qt_add_qml_module(lingua_spanner_helper
    URI             LinguaSpannerHelper
    VERSION         1.0.0
    SOURCES
        src/ProcessHelper.h
        src/ProcessHelper.cpp
    OUTPUT_DIRECTORY "${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper"
)

set_target_properties(lingua_spanner_helperplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    BUILD_RPATH "$ORIGIN"
)

target_include_directories(lingua_spanner_helper PRIVATE
    ${CMAKE_SOURCE_DIR}/src
)

install(TARGETS lingua_spanner_helper
    LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/LinguaSpannerHelper/qmldir"
    DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper
)
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/LinguaSpannerHelper/plugins.qmltypes"
    DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper
    OPTIONAL
)
