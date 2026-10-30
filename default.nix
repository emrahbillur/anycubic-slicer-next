{ lib
, stdenv
, cmake
, ninja
, pkg-config
, src
# Build tools
, boost1_84_0
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
, wxWidgets_3_2
, libsystemd
, xorg
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
    boost1_84_0
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
    wxWidgets_3_2
    libsystemd
    xorg.libX11
    xorg.libXrandr
    xorg.libXi
    xorg.libXrender
    xorg.libXext
    xorg.libxcb
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXcomposite
    atk
    pango
    cairo
    fontconfig
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
