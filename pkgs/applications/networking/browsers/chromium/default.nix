{ stdenv, fetchurl, fetchsvn, makeWrapper
, python, perl, pkgconfig
, nspr, nss, udev, bzip2
, utillinux, alsaLib
, gcc, bison, gperf
, krb5
, glib, gtk, gconf, libgcrypt, libgnome_keyring, dbus_glib
, libXScrnSaver, libXcursor

, useSELinux ? false
, naclSupport ? false
, gnomeKeyringSupport ? false
, useProprietaryCodecs ? false
}:

let
  mkGypFlags = with stdenv.lib; let
    sanitize = value:
      if value == true then "1"
      else if value == false then "0"
      else "${value}";
    toFlag = key: value: "-D${key}=${sanitize value}";
  in attrs: concatStringsSep " " (attrValues (mapAttrs toFlag attrs));

in stdenv.mkDerivation rec {
  name = "chromium-${version}";

  version = "21.0.1171.0";

  src = fetchurl {
    url = "http://commondatastorage.googleapis.com/chromium-browser-official/chromium-${version}.tar.bz2";
    sha256 = "3fd9b2d8895750a4435a585b9c2dc7d34b583c6470ba67eb6ea6c2579f126377";
  };

  buildInputs = [
    makeWrapper
    python perl pkgconfig
    nspr nss udev bzip2
    utillinux alsaLib
    gcc bison gperf
    krb5
    glib gtk gconf libgcrypt dbus_glib
    libXScrnSaver libXcursor
  ] ++ stdenv.lib.optional gnomeKeyringSupport libgnome_keyring;

  prePatch = "patchShebangs .";

  gypFlags = mkGypFlags {
    linux_use_gold_binary = false;
    linux_use_gold_flags = false;
    proprietary_codecs = false;
    use_gnome_keyring = gnomeKeyringSupport;
    disable_nacl = !naclSupport;
    use_cups = false;
  };

  /* TODO:
  use_system_bzip2 = true;
  use_system_ffmpeg = true;
  use_system_flac = true;
  use_system_harfbuzz = true;
  use_system_icu = true;
  use_system_libevent = true;
  use_system_libexpat = true;
  use_system_libjpeg = true;
  use_system_libpng = true;
  use_system_libwebp = true;
  use_system_libxml = true;
  use_system_skia = true;
  use_system_speex = true;
  use_system_sqlite = true;
  use_system_ssl = true;
  use_system_stlport = true;
  use_system_v8 = true;
  use_system_xdg_utils = true;
  use_system_yasm = true;
  use_system_zlib = true;
  */

  configurePhase = ''
    python build/gyp_chromium --depth $(pwd) ${gypFlags}
  '';

  buildPhase = ''
    make CC=${gcc}/bin/gcc BUILDTYPE=Release library=shared_library chrome chrome_sandbox
  '';

  installPhase = ''
    mkdir -vp "$out/libexec/chrome"
    cp -v "out/${buildType}/"*.pak "$out/libexec/chrome/"
    cp -vR "out/${buildType}/locales" "out/${buildType}/resources" "$out/libexec/chrome/"

    cp -v "out/${buildType}/chrome" "$out/libexec/chrome/chrome"

    mkdir -vp "$out/bin"
    makeWrapper "$out/libexec/chrome/chrome" "$out/bin/chrome"

    mkdir -vp "$out/share/man/man1"
    cp -v "out/${buildType}/chrome.1" "$out/share/man/man1/chrome.1"

    for icon_file in chrome/app/theme/chromium/product_logo_*[0-9].png; do
      num_and_suffix="''${icon_file##*logo_}"
      icon_size="''${num_and_suffix%.*}"
      logo_output_path="$out/share/icons/hicolor/''${icon_size}x''${icon_size}/apps"
      mkdir -vp "$logo_output_path"
      cp -v "$icon_file" "$logo_output_path/chrome.png"
    done
  '';

  meta =  with stdenv.lib; {
    description = "Chromium, an open source web browser";
    homepage = http://www.chromium.org/;
    maintainers = with stdenv.lib.maintainers; [ goibhniu chaoflow ];
    license = licenses.bsd3;
  };
}
