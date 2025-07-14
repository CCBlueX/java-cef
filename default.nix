{ pkgs ? import <nixpkgs> {} }:

assert !pkgs.stdenv.hostPlatform.isDarwin;
# I can't test darwin

let
  rpath = pkgs.lib.makeLibraryPath (with pkgs; [
    glib
    nss
    nspr
    atk
    at-spi2-atk
    libdrm
    libGL
    expat
    xorg.libxcb
    libxkbcommon
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    mesa
    gtk3
    pango
    cairo
    alsa-lib
    dbus
    at-spi2-core
    cups
    xorg.libxshmfence
    udev
    libgbm
  ]);
  debugBuild = false;
  buildType = if debugBuild then "Debug" else "Release";
  platform =
    {
      "aarch64-linux" = "linuxarm64";
      "x86_64-linux" = "linux64";
    }
    .${pkgs.stdenv.hostPlatform.system} or (throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}");
  arches =
    {
      "linuxarm64" = {
        depsArch = "arm64";
        projectArch = "arm64";
        targetArch = "arm64";
      };
      "linux64" = {
        depsArch = "amd64";
        projectArch = "x86_64";
        targetArch = "x86_64";
      };
    }
    .${platform};
  cef_version = "135.0.20+ge7de5c3+chromium-135.0.7049.85";
  inherit (arches) depsArch projectArch targetArch;

in
pkgs.stdenv.mkDerivation rec {
  pname = "jcef-ccbluex";
  rev = "eaeb3d4370aa3526ee237ad1981ad59af3de4dd1";
  version = "458";

  nativeBuildInputs = with pkgs; [
    cmake
    git
    jdk
    ninja
    python3
    bintools
    strip-nondeterminism
  ];
  buildInputs = with pkgs; [
    boost
    xorg.libX11
    xorg.libXdamage
    nss
    nspr
    thrift
  ];

  src = ./.;
  cef-bin =
    let
      # `cef_binary_${CEF_VERSION}_linux64_minimal`, where CEF_VERSION is from $src/CMakeLists.txt
      name = "cef_binary_${cef_version}_${platform}";
      hash =
        {
          "linux64" = "sha256-hnndcV5UhCHa4VZOLajiPfejEXWrvCgxsFe2+a80t+Y=";
        }
        .${platform};
      urlName = builtins.replaceStrings [ "+" ] [ "%2B" ] name;
    in
    pkgs.fetchzip {
      url = "https://cef-builds.spotifycdn.com/${urlName}.tar.bz2";
      inherit name hash;
    };
  # Find the hash in tools/buildtools/linux64/clang-format.sha1
  clang-fmt = pkgs.fetchurl {
    url = "https://storage.googleapis.com/chromium-clang-format/dd736afb28430c9782750fc0fd5f0ed497399263";
    hash = "sha256-4H6FVO9jdZtxH40CSfS+4VESAHgYgYxfCBFSMHdT0hE=";
  };
  releaseName = {
          "linux64" = "linux_amd64";
  }.${platform};

  configurePhase = ''
    runHook preConfigure

    patchShebangs .

    cp -r ${cef-bin} third_party/cef/${cef-bin.name}
    chmod +w -R third_party/cef/${cef-bin.name}
    patchelf third_party/cef/${cef-bin.name}/${buildType}/libcef.so --set-rpath "${rpath}" --add-needed libudev.so
    patchelf third_party/cef/${cef-bin.name}/${buildType}/libGLESv2.so --set-rpath "${rpath}" --add-needed libGL.so.1
    patchelf third_party/cef/${cef-bin.name}/${buildType}/chrome-sandbox --set-interpreter $(cat $NIX_BINTOOLS/nix-support/dynamic-linker)
    sed 's/-O0/-O2/' -i third_party/cef/${cef-bin.name}/cmake/cef_variables.cmake

    sed \
      -e 's|os.path.isdir(os.path.join(path, \x27.git\x27))|True|' \
      -e 's|"%s rev-parse %s" % (git_exe, branch)|"echo '${rev}'"|' \
      -e 's|"%s config --get remote.origin.url" % git_exe|"echo 'https://github.com/jetbrains/jcef'"|' \
      -e 's|"%s rev-list --count %s" % (git_exe, branch)|"echo '${version}'"|' \
      -i tools/git_util.py

    cp ${clang-fmt} tools/buildtools/linux64/clang-format
    chmod +w tools/buildtools/linux64/clang-format

    sed \
      -e 's|include(cmake/vcpkg.cmake)||' \
      -e 's|bring_vcpkg()||' \
      -e 's|vcpkg_install_package(boost-filesystem boost-interprocess thrift)||' \
      -i CMakeLists.txt

    mkdir jcef_build
    cd jcef_build

    cmake -G "Ninja" -DPROJECT_ARCH="${projectArch}" -DCMAKE_BUILD_TYPE=${buildType} ..

    runHook postConfigure
  '';

  installPhase = ''
        export JCEF_ROOT_DIR=$(realpath ..)
        export OUT_NATIVE_DIR=$JCEF_ROOT_DIR/jcef_build/native/${buildType}
        strip $OUT_NATIVE_DIR/libcef.so
        strip-nondeterminism $OUT_NATIVE_DIR/libcef.so
        mkdir -p $out/
        cp -R "$OUT_NATIVE_DIR"/* $out/
  '';

  postBuild = ''
    export JCEF_ROOT_DIR=$(realpath ..)
  '';
  fixupPhase = ''
    export JCEF_ROOT_DIR=$(realpath ..)
  '';


  dontStrip = debugBuild;

  meta = {
    description = "CCBlueX' fork of JCEF";
    license = pkgs.lib.licenses.bsd3;
    homepage = "https://github.com/CCBlueX/java-cef";
  };
}
