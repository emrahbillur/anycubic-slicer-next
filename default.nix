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

  preBuild = ''
    sed -i "s/+UNKNOWN/_$(date '+%F')/" version.inc || true
  '';

  # Boost 1.91 BoostConfig.cmake component cmake dosyalarını üretmiyor.
  # Nixpkgs boost paketindeki cmake-paths patch'leri de bu sorunu çözemedi.
  # Çözüm: CMakeLists.txt patch ile find_package(Boost ...) yerine
  # FindBoost modülünü kullanmaya zorla.
  postPatch = ''
    # Boost_CONFIG_FILE yerine FindBoost kullan
    sed -i 's/find_package(Boost/find_package(Boost)/' CMakeLists.txt
    # CMake cache'e BOOST_NO_BOOST_CMAKE=ON yaz
    # Böylece BoostConfig.cmake bypass edilir
  '';

  buildPhase = ''
    runHook preBuild
    mkdir build
    cd build
    cmake .. \
      -DCMAKE_INSTALL_PREFIX="$out" \
      -DCMAKE_BUILD_TYPE=Release \
      -DSLIC3R_STATIC=1 \
      -DSLIC3R_GUI=1 \
      -DSLIC3R_PCH=OFF \
      -DBOOST_ROOT="${boost}" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBoost_NO_BOOST_CMAKE=ON \
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
