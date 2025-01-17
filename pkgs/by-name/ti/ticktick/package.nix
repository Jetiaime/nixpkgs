{
  lib,
  fetchurl,
  stdenv,
  wrapGAppsHook3,
  dpkg,
  autoPatchelfHook,
  glibc,
  gcc-unwrapped,
  nss,
  libdrm,
  libgbm,
  alsa-lib,
  xdg-utils,
  systemd,
  makeWrapper,
  undmg,
  unzip,
}:
let
  pname = "ticktick";
  version = if stdenv.hostPlatform.isDarwin then "6.1.40_400" else "6.0.20";

  meta = with lib; {
    description = "Powerful to-do & task management app with seamless cloud synchronization across all your devices";
    homepage = "https://ticktick.com/home/";
    license = licenses.unfree;
    maintainers = with maintainers; [
      hbjydev
      Jetiaime
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };

  os_path = if stdenv.hostPlatform.isDarwin then "mac" else "linux/linux_deb_x64";
  filename = if stdenv.hostPlatform.isDarwin then "TickTick_${version}.dmg" else "ticktick-${version}-amd64.deb";

  src = fetchurl {
    url = "https://d2atcrkye2ik4e.cloudfront.net/download/${os_path}/${filename}";
    hash =
      if stdenv.hostPlatform.isDarwin then
        "sha256-+qGKbnpzF9GZ9HPjywJGJdopsbPWNqv9TPtAwm6Wr/s=";
      else
        "sha256-aKUK0/9Y/ac9ISYJnWDUdwmvN8UYKzTY0f94nd8ofGw=";
  }
  .${stdenv.system} or (throw "ticktick: ${stdenv.system} is unsupported.");

  linux = stdenv.mkDerivation {
    inherit
      pname
      version
      src 
    ;

    meta = meta // {
      platforms = [
        "x86_64-linux"
      ];
    };

    nativeBuildInputs = [
      wrapGAppsHook3
      autoPatchelfHook
      dpkg
    ];

    buildInputs = [
      nss
      glibc
      libdrm
      gcc-unwrapped
      libgbm
      alsa-lib
      xdg-utils
    ];

    # Needed to make the process get past zygote_linux fork()'ing
    runtimeDependencies = [
      systemd
    ];

    unpackPhase = ''
      runHook preUnpack

      mkdir -p "$out/share" "$out/opt/${pname}" "$out/bin"
      dpkg-deb --fsys-tarfile "$src" | tar --extract --directory="$out"

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      cp -av $out/opt/TickTick/* $out/opt/${pname}
      cp -av $out/usr/share/* $out/share
      rm -rf $out/usr $out/opt/TickTick
      ln -sf "$out/opt/${pname}/${pname}" "$out/bin/${pname}"

      substituteInPlace "$out/share/applications/${pname}.desktop" \
        --replace "Exec=/opt/TickTick/ticktick" "Exec=$out/bin/${pname}"

      runHook postInstall
    '';
  }

  darwin = stdenv.mkDerivation {
    inherit
      pname
      version
      src
    ;

    meta = meta // {
      platforms = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    };

    sourceRoot = "${pname}.app";

    nativeBuildInputs = [
      makeWrapper
      undmg
      unzip
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/{Applications/${pname}.app,bin}
      cp -R . $out/Applications/${appname}.app
      makeWrapper $out/Applications/${appname}.app/Contents/MacOS/${appname} $out/bin/${pname}
      runHook postInstall
    '';
  };
in
if stdenv.hostPlatform.isLinux then linux else darwin
