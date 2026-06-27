cmake_minimum_required(VERSION 3.16)
project(lingua-spanner VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}" CACHE PATH "Install prefix")

# ── Qt6 QML module (ProcessHelper + AtspiCursorReader) ────
# No KF6 needed — Qt6::Core + Qt6::DBus + Qt6::Qml only.
find_package(Qt6 6.7 REQUIRED COMPONENTS Core DBus Qml)

qt_policy(SET QTP0001 NEW)

qt_add_qml_module(lingua_spanner_helper
    URI             LinguaSpannerHelper
    VERSION         1.0.0
    SOURCES
        src/ProcessHelper.h
        src/ProcessHelper.cpp
        src/AtspiCursorReader.h
        src/AtspiCursorReader.cpp
    OUTPUT_DIRECTORY "${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper"
)

set_target_properties(lingua_spanner_helperplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    BUILD_RPATH "$ORIGIN"
)

target_link_libraries(lingua_spanner_helper PRIVATE
    Qt6::DBus
)

target_include_directories(lingua_spanner_helper PRIVATE
    ${CMAKE_SOURCE_DIR}/src
)

install(TARGETS lingua_spanner_helper
    LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper
)

# Install the generated qmldir + friends
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/LinguaSpannerHelper/qmldir"
    DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper
)
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/LinguaSpannerHelper/plugins.qmltypes"
    DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qml/LinguaSpannerHelper
    OPTIONAL
)

# ── Optional: KF6 Applet (skipped if headers missing) ──────
find_package(ECM QUIET)
if(ECM_FOUND)
    set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
    include(KDEInstallDirs)
    include(KDECMakeSettings)
    include(KDECompilerSettings NO_POLICY_SCOPE)

    find_package(Qt6 6.7 QUIET COMPONENTS DBus Quick)
    find_package(KF6 6.0 QUIET COMPONENTS Plasma I18n Config)

    if(KF6_FOUND)
        set(lingua_spanner_applet_SRCS
            src/mainapplet.cpp
            src/atspitextreader.cpp
            src/htmlparser.cpp
            src/ocrrunner.cpp
        )

        plasma_add_applet(org.kde.lingua-spanner
            CPP_SOURCES  ${lingua_spanner_applet_SRCS}
            QML_SOURCES  ui/main.qml
        )

        target_link_libraries(org.kde.lingua-spanner PRIVATE
            Qt6::Core Qt6::DBus Qt6::Qml Qt6::Quick
            KF6::Plasma KF6::I18n KF6::Config
        )

        find_package(lexbor QUIET COMPONENTS html css dom)
        if(lexbor_FOUND)
            target_link_libraries(org.kde.lingua-spanner PRIVATE
                liblexbor-html liblexbor-css liblexbor-dom liblexbor-core
            )
        endif()

        install(TARGETS org.kde.lingua-spanner
            DESTINATION ${KDE_INSTALL_PLUGINDIR}/plasma/applets
        )
        plasma_install_package(package org.kde.lingua-spanner)
    endif()
endif()
