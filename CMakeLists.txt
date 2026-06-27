cmake_minimum_required(VERSION 3.16)
project(lingua-spanner VERSION 1.0.0 LANGUAGES CXX C)

# ── KDE Framework setup ──────────────────────────────────────────
set(QT_MIN_VERSION "6.7.0")
set(KF6_MIN_VERSION "6.0.0")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)

# ── Qt6 dependencies ─────────────────────────────────────────────
find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core        # QObject, QString, etc.
    DBus        # QDBusConnection, QDBusInterface
    Qml         # QML engine integration
    Quick       # Qt Quick (PlasmoidItem)
)

# ── KF6 dependencies ─────────────────────────────────────────────
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Plasma      # Plasma::Applet, plasma_add_applet()
    I18n        # i18n() translations
    Config      # KConfig for settings
)

# ── lexbor (HTML/CSS parser) ─────────────────────────────────────
# Try CMake config first, then fallback to pkg-config
find_package(lexbor QUIET COMPONENTS html css dom)
if(NOT lexbor_FOUND)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(LEXBOR REQUIRED IMPORTED_TARGET
        lexbor-html
        lexbor-css
        lexbor-dom
    )
    set(LEXBOR_LIBRARY PkgConfig::LEXBOR)
else()
    set(LEXBOR_LIBRARY
        liblexbor-html
        liblexbor-css
        liblexbor-dom
        liblexbor-core
    )
endif()

# ── Source files ─────────────────────────────────────────────────
set(lingua_spanner_SRCS
    src/mainapplet.cpp
    src/atspitextreader.cpp
    src/htmlparser.cpp
    src/ocrrunner.cpp
)

# ── Plasma Applet registration ───────────────────────────────────
plasma_add_applet(org.kde.lingua-spanner
    CPP_SOURCES  ${lingua_spanner_SRCS}
    QML_SOURCES  ui/main.qml
)

target_link_libraries(org.kde.lingua-spanner PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Qml
    Qt6::Quick
    KF6::Plasma
    KF6::I18n
    KF6::Config
    ${LEXBOR_LIBRARY}
)

# ── Install ──────────────────────────────────────────────────────
install(TARGETS org.kde.lingua-spanner
    DESTINATION ${KDE_INSTALL_PLUGINDIR}/plasma/applets
)

plasma_install_package(package org.kde.lingua-spanner)

# ── Feature summary ──────────────────────────────────────────────
feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES)
