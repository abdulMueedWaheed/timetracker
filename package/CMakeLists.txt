cmake_minimum_required(VERSION 3.16)
project(timetracker VERSION 0.1 LANGUAGES NONE)

include(GNUInstallDirs)

set(APPLET_ID "com.github.abdulMueedWhaeed.timetracker")
set(APPLET_INSTALL_DIR "${CMAKE_INSTALL_DATADIR}/plasma/plasmoids/${APPLET_ID}")

install(FILES metadata.json
    DESTINATION "${APPLET_INSTALL_DIR}"
)

install(DIRECTORY contents/
    DESTINATION "${APPLET_INSTALL_DIR}/contents"
)