{ lib
, stdenv
, cmake
, ninja
, pkg-config
, makeWrapper
, wrapGAppsHook3
, src
, libnoiseSrc
, boost
, tbb
, openssl
, curl
, freetype
, zlib
, libpng
, libjpeg
, expat
, mesa
, gtk3
, libsecret
, gst_all_1
, glew
, glfw
, cereal
, nlopt
, openvdb
, imath
, cgal
, mpfr
, opencv
, opencascade-occt
, dbus
, wxwidgets_3_2
, systemdLibs
, libX11
, webkitgtk_4_1
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "anycubic-slicer-next";
  version = "unstable-2026-10-30";

  patches = [
    ./boost-191-compat.patch
    ./boost-process-v1.patch
  ];

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    boost
    tbb
    openssl
    curl
    freetype
    zlib
    libpng
    libjpeg
    expat
    mesa
    gtk3
    libsecret
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    glew
    glfw
    cereal
    nlopt
    openvdb
    imath
    cgal
    mpfr
    opencv
    opencascade-occt
    dbus
    wxwidgets_3_2
    systemdLibs
    libX11
    webkitgtk_4_1.dev
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DSLIC3R_STATIC=0"
    "-DSLIC3R_GUI=1"
    "-DSLIC3R_GTK=3"
    "-DSLIC3R_PCH=OFF"
    "-DImath_DIR=${imath}/lib/cmake/Imath"
    "-DCMAKE_CXX_FLAGS=-I${opencv}/include/opencv4 -Wno-error=return-type -Wno-error=maybe-uninitialized"
  ];

  preBuild = ''
    sed -i "s/+UNKNOWN/_$(date '+%F')/" version.inc || true
  '';

  postPatch = ''
    # Utils.hpp declares std::filesystem::path but does not include its header.
    sed -i '1i#include <filesystem>' src/libslic3r/Utils.hpp
    # Boost 1.91 keeps the index loader on boost::filesystem::path while this
    # code enumerates entries with std::filesystem.
    substituteInPlace src/slic3r/Config/Version.cpp \
      --replace-fail 'idx.load(dir_entry.path());' \
                     'idx.load(boost::filesystem::path(dir_entry.path().string()));'
    substituteInPlace src/slic3r/GUI/MediaPlayCtrl.cpp \
      --replace-fail 'boost::process::pipe intermediate;' \
                     'boost::process::v1::pipe intermediate;' \
      --replace-fail 'boost::process::start_dir(' \
                     'boost::process::v1::start_dir(' \
      --replace-fail 'boost::process::std_out' \
                     'boost::process::v1::std_out' \
      --replace-fail 'boost::process::std_in' \
                     'boost::process::v1::std_in' \
      --replace-fail 'boost::process::limit_handles' \
                     'boost::process::v1::limit_handles'
    sed -i '18i#include <boost/process/v1/start_dir.hpp>\n#include <boost/process/v1/handles.hpp>' \
      src/slic3r/GUI/MediaPlayCtrl.cpp
    substituteInPlace src/slic3r/GUI/RemovableDriveManager.cpp \
      --replace-fail 'boost::process::search_path(' \
                     'boost::process::v1::search_path(' \
      --replace-fail 'boost::process::std_out' \
                     'boost::process::v1::std_out' \
      --replace-fail 'boost::process::std_err' \
                     'boost::process::v1::std_err'
    sed -i '28i#include <boost/process/v1/search_path.hpp>' \
      src/slic3r/GUI/RemovableDriveManager.cpp
    substituteInPlace src/slic3r/Utils/Bonjour.cpp \
      --replace-fail 'boost::asio::io_service' 'boost::asio::io_context' \
      --replace-fail 'asio::deadline_timer' 'asio::steady_timer' \
      --replace-fail 'io_service->post(' 'boost::asio::post(*io_service, ' \
      --replace-fail 'timer.expires_from_now(boost::posix_time::seconds(timeout));' \
                     'timer.expires_after(std::chrono::seconds(timeout));'
    substituteInPlace src/slic3r/Utils/Serial.hpp src/slic3r/Utils/Serial.cpp \
      --replace-quiet 'boost::asio::io_service' 'boost::asio::io_context' \
      --replace-quiet 'asio::io_service' 'asio::io_context'
    substituteInPlace src/slic3r/Utils/TCPConsole.cpp \
      --replace-fail 'endpoints->endpoint()' 'endpoints.begin()->endpoint()'
    substituteInPlace src/slic3r/GUI/Widgets/StateColor.cpp \
      --replace-fail 'wxASSERT(iter != gDarkColors.end());' \
                     '// Unmapped colors use the original-color fallback below.' \
      --replace-fail 'wxASSERT(iter != gLightColors.end());' \
                     '// Unmapped colors use the original-color fallback below.'
    substituteInPlace src/slic3r/GUI/Widgets/SideTools.cpp \
      --replace-fail 'wxDefaultSize,wxALIGN_CENTER_HORIZONTAL | wxST_ELLIPSIZE_END);' \
                     'wxDefaultSize,wxHL_ALIGN_CENTRE);'
    substituteInPlace src/slic3r/GUI/Widgets/AMSControl.cpp \
      --replace-fail 'wxID_ANY, wxEmptyString, wxEmptyString, wxDefaultPosition' \
                     'wxID_ANY, wxT(" "), wxEmptyString, wxDefaultPosition'
    substituteInPlace src/slic3r/GUI/CalibrationWizardPresetPage.cpp \
      --replace-fail 'm_top_sizer->Add(m_pa_cali_method_combox, 0);' \
                     'if (m_pa_cali_method_combox) m_top_sizer->Add(m_pa_cali_method_combox, 0);'
    substituteInPlace src/slic3r/GUI/PresetComboBoxes.cpp \
      --replace-fail 'GList* cells = gtk_cell_layout_get_cells(GTK_CELL_LAYOUT(m_widget));' \
                     'GList* cells = GTK_IS_CELL_LAYOUT(m_widget) ? gtk_cell_layout_get_cells(GTK_CELL_LAYOUT(m_widget)) : nullptr;'
    sed -i '/CallAfter.*addScriptMessageHandler.*{/a\
            webView->CallAfter([webView, addScriptMessageHandler] {' \
      src/slic3r/GUI/Widgets/WebView.cpp
    sed -i '/webView->EnableContextMenu(true);/i\
        });' src/slic3r/GUI/Widgets/WebView.cpp
    # OCCT 7.9 consolidated the legacy STEP libraries into TKDESTEP, and
    # nixpkgs builds OpenCV as component libraries rather than opencv_world.
    substituteInPlace src/libslic3r/CMakeLists.txt \
      --replace-fail 'TKXDESTEP' 'TKDESTEP' \
      --replace-fail 'TKSTEP209' 'TKDESTEP' \
      --replace-fail 'TKSTEPAttr' 'TKDESTEP' \
      --replace-fail 'TKSTEPBase' 'TKDESTEP' \
      --replace-fail 'TKSTEP' 'TKDESTEP' \
      --replace-fail 'opencv_world' 'opencv_core opencv_imgproc opencv_imgcodecs'
    substituteInPlace src/CMakeLists.txt \
      --replace-fail 'set_target_properties(OrcaSlicer PROPERTIES OUTPUT_NAME "orca-slicer")' \
                     'set_target_properties(OrcaSlicer PROPERTIES OUTPUT_NAME "AnycubicSlicerNext")' \
      --replace-fail 'set(SLIC3R_APP_CMD "orca-slicer")' \
                     'set(SLIC3R_APP_CMD "AnycubicSlicerNext")' \
      --replace-fail 'target_link_libraries(OrcaSlicer libslic3r cereal::cereal)' \
                     'target_link_libraries(OrcaSlicer libslic3r cereal::cereal X11)'
    substituteInPlace src/slic3r/CMakeLists.txt \
      --replace-fail 'pkg_check_modules(LIBSECRET REQUIRED libsecret-1)' \
                     'pkg_check_modules(LIBSECRET REQUIRED libsecret-1)
    pkg_check_modules(WEBKIT2GTK REQUIRED IMPORTED_TARGET webkit2gtk-4.1)
    target_link_libraries(libslic3r_gui PkgConfig::WEBKIT2GTK)'
    substituteInPlace src/slic3r/GUI/PhysicalPrinterDialog.cpp \
      --replace-fail 'choice->set_values({ m_config->opt_string("printhost_port") });' \
                     'choice->set_values(std::vector<std::string>{ m_config->opt_string("printhost_port") });'
    substituteInPlace src/libslic3r/GCode/PostProcessor.cpp \
      src/slic3r/GUI/RemovableDriveManager.cpp \
      src/slic3r/GUI/MediaPlayCtrl.cpp \
      --replace-fail '#include <boost/process.hpp>' '#include <boost/process/v1.hpp>'

    # Boost 1.91 BoostConfig.cmake does not provide component config files.
    # Use FindBoost module instead.
    cat > cmake/modules/FindBoost.cmake <<'EOF'
    find_path(Boost_INCLUDE_DIR NAMES boost/version.hpp REQUIRED)
    set(Boost_INCLUDE_DIRS "''${Boost_INCLUDE_DIR}")
    file(STRINGS "''${Boost_INCLUDE_DIR}/boost/version.hpp" _boost_version_line
      REGEX "^#define BOOST_VERSION [0-9]+$")
    string(REGEX MATCH "[0-9]+" Boost_VERSION "''${_boost_version_line}")
    math(EXPR _boost_major "''${Boost_VERSION} / 100000")
    math(EXPR _boost_minor "(''${Boost_VERSION} / 100) % 1000")
    math(EXPR _boost_patch "''${Boost_VERSION} % 100")
    set(Boost_VERSION_STRING "''${_boost_major}.''${_boost_minor}.''${_boost_patch}")
    if(NOT TARGET Boost::boost)
      add_library(Boost::boost INTERFACE IMPORTED)
      set_target_properties(Boost::boost PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "''${Boost_INCLUDE_DIR}")
    endif()
    set(_Boost_COMPONENTS ''${Boost_FIND_COMPONENTS})
    foreach(_component IN LISTS _Boost_COMPONENTS)
      if(_component STREQUAL "system")
        if(NOT TARGET Boost::system)
          add_library(Boost::system INTERFACE IMPORTED)
          set_target_properties(Boost::system PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "''${Boost_INCLUDE_DIR}")
        endif()
        set(Boost_system_FOUND TRUE)
        set(Boost_SYSTEM_FOUND TRUE)
        list(APPEND Boost_LIBRARIES Boost::system)
        continue()
      endif()
      find_library(Boost_''${_component}_LIBRARY
        NAMES boost_''${_component}
        REQUIRED)
      if(NOT TARGET Boost::''${_component})
        add_library(Boost::''${_component} UNKNOWN IMPORTED)
        set_target_properties(Boost::''${_component} PROPERTIES
          IMPORTED_LOCATION "''${Boost_''${_component}_LIBRARY}"
          INTERFACE_INCLUDE_DIRECTORIES "''${Boost_INCLUDE_DIR}")
      endif()
      set(Boost_''${_component}_FOUND TRUE)
      string(TOUPPER "''${_component}" _component_upper)
      set(Boost_''${_component_upper}_FOUND TRUE)
      list(APPEND Boost_LIBRARIES Boost::''${_component})
    endforeach()
    include(FindPackageHandleStandardArgs)
    find_package_handle_standard_args(Boost
      REQUIRED_VARS Boost_INCLUDE_DIR
      VERSION_VAR Boost_VERSION_STRING
      HANDLE_COMPONENTS)
    EOF
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(SLIC3R_APP_CMD "orca-slicer")' \
                     'set(SLIC3R_APP_CMD "AnycubicSlicerNext")' \
      --replace-fail 'cmake_policy(SET CMP0167 NEW)' 'cmake_policy(SET CMP0167 OLD)' \
      --replace-fail 'find_package(Boost 1.83.0 REQUIRED COMPONENTS' \
                     'find_package(Boost 1.83.0 MODULE REQUIRED COMPONENTS' \
      --replace-fail 'list(APPEND CMAKE_MODULE_PATH ''${PROJECT_SOURCE_DIR}/cmake/modules/)' \
                     'list(PREPEND CMAKE_MODULE_PATH ${openvdb}/lib/cmake/OpenVDB ''${PROJECT_SOURCE_DIR}/cmake/modules/)'
    substituteInPlace cmake/modules/FindOpenVDB.cmake \
      --replace-fail 'find_package(IlmBase QUIET)' \
                     'find_package(IlmBase QUIET)
    find_package(Imath CONFIG QUIET)
    if(TARGET Imath::Imath AND NOT TARGET IlmBase::Half)
      add_library(IlmBase::Half INTERFACE IMPORTED)
      target_link_libraries(IlmBase::Half INTERFACE Imath::Imath)
      set(IlmBase_FOUND TRUE)
    endif()'
  '';

  buildPhase = ''
    runHook preBuild
    cmake -S ${libnoiseSrc} -B libnoise-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_INSTALL_PREFIX="$PWD/libnoise-prefix"
    cmake --build libnoise-build --parallel "$NIX_BUILD_CORES"
    cmake --install libnoise-build
    mkdir build
    cd build
    cmake .. \
      -DCMAKE_INSTALL_PREFIX="$out" \
      -DCMAKE_PREFIX_PATH="$PWD/../libnoise-prefix;${openvdb}/lib/cmake/OpenVDB" \
      -DLIBNOISE_INCLUDE_DIR="$PWD/../libnoise-prefix/include" \
      -DLIBNOISE_LIBRARY="$PWD/../libnoise-prefix/lib/liblibnoise_static.a" \
      -DCMAKE_BUILD_TYPE=Release \
      -DSLIC3R_STATIC=0 \
      -DSLIC3R_GUI=1 \
      -DSLIC3R_GTK=3 \
      -DSLIC3R_PCH=OFF \
      -DImath_DIR=${imath}/lib/cmake/Imath \
      "-DCMAKE_CXX_FLAGS=-I${opencv}/include/opencv4 -Wno-error=return-type -Wno-error=maybe-uninitialized" \
      -G Ninja
    cmake --build . --target all -- -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cmake --install . --prefix "$out"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/AnycubicSlicerNext" \
      --set WXSUPPRESS_SIZER_FLAGS_CHECK 1
    ln -s AnycubicSlicerNext "$out/bin/orca-slicer"
    install -Dm644 "$out/resources/images/AnycubicSlicer.png" \
      "$out/share/icons/hicolor/256x256/apps/AnycubicSlicer.png"
    install -Dm644 /dev/null "$out/share/applications/anycubic-slicer-next.desktop"
    cat > "$out/share/applications/anycubic-slicer-next.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=AnycubicSlicerNext
    Comment=Anycubic 3D printer slicer
    Exec=$out/bin/AnycubicSlicerNext %F
    Icon=$out/resources/images/AnycubicSlicer.png
    Terminal=false
    Categories=Graphics;3DGraphics;
    StartupWMClass=AnycubicSlicerNext
    EOF
    rm -f "$out/resources/applications/OrcaSlicer.desktop"
  '';

  inherit src;

  dontConfigure = true;

  meta = with lib; {
    description = "Anycubic 3D printer slicer - fork of OrcaSlicer";
    homepage = "https://github.com/ANYCUBIC-3D/AnycubicSlicerNext";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [];
  };
})
