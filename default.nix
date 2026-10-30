{ lib
, stdenv
, cmake
, ninja
, pkg-config
, src
, boost
, tbb
, openssl
, curl
, freetype
, zlib
, libpng
, mesa
, glew
, glfw
, cereal
, nlopt
, openvdb
, dbus
, wxwidgets_3_2
, systemdLibs
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "anycubic-slicer-next";
  version = "unstable-2026-10-30";

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    boost
    tbb
    openssl
    curl
    freetype
    zlib
    libpng
    mesa
    glew
    glfw
    cereal
    nlopt
    openvdb
    dbus
    wxwidgets_3_2
    systemdLibs
  ];

  cmakeFlags = [
    "-DSLIC3R_STATIC=1"
    "-DSLIC3R_GUI=1"
    "-DSLIC3R_PCH=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_CXX_FLAGS=-Wno-error=return-type"
  ];

  preBuild = ''
    sed -i "s/+UNKNOWN/_$(date '+%F')/" version.inc || true
  '';

  # Boost 1.91'de BoostConfig.cmake component cmake dosyalarını bulamıyor.
  # Boost_DIR cache değişkeni ile FindBoost modülünü kullanmaya zorla.
  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DSLIC3R_STATIC=1"
    "-DSLIC3R_GUI=1"
    "-DSLIC3R_PCH=OFF"
    "-DCMAKE_CXX_FLAGS=-Wno-error=return-type"
    "-DBOOST_ROOT=${boost}"
  ];

  # Boost component config dosyaları yerine FindBoost kullan
  postConfigure = ''
    # Boost_DIR'i cmake cache'e yazarak BoostConfig.cmake bypass et
    echo "set(Boost_DIR \"\")" >> CMakeCache.txt
    echo "set(Boost_NO_BOOST_CMAKE ON)" >> CMakeCache.txt
  '';

  buildPhase = ''
    runHook preBuild
    mkdir build
    cd build
    cmake .. \
      -DCMAKE_INSTALL_PREFIX="$out" \
      -DBOOST_ROOT="${boost}" \
      -DBOOST_NO_BOOST_CMAKE=ON \
      -G Ninja
    cmake --build . --target all -- -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cd build
    cmake --install . --prefix "$out"
    runHook postInstall
  '';

  inherit src;

  meta = with lib; {
    description = "Anycubic 3D printer slicer - fork of OrcaSlicer";
    homepage = "https://github.com/ANYCUBIC-3D/AnycubicSlicerNext";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [];
  };
})
