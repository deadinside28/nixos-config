# nix-ld: запуск сторонних динамически слинкованных бинарников,
# рассчитанных на FHS-систему.
{pkgs, ...}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Базовые системные библиотеки
      stdenv.cc.cc.lib
      glibc
      zlib
      openssl
      fuse
      fuse3
      icu
      libuuid
      libxml2
      libsecret
      harfbuzz
      freetype
      fontconfig

      # Графика и UI-тулкиты
      mesa
      libGL
      libGLU
      libepoxy
      libdrm
      vulkan-loader
      gtk3
      gtk4
      libadwaita
      pango
      cairo
      atk
      gdk-pixbuf
      glib

      # X11 и Wayland
      wayland
      libX11
      libXext
      libXrender
      libXfixes
      libXcomposite
      libXdamage
      libXcursor
      libXi
      libXrandr
      libXScrnSaver
      libXtst
      libxcb
      libxkbcommon

      # Звук и медиа
      alsa-lib
      libpulseaudio
      pipewire
      cups
      ffmpeg

      # Electron и браузерные движки
      nss
      nspr
      expat
      dbus
      at-spi2-core

      # Аудио, ввод и легаси-стек для эмуляторов
      openal
      libjack2
      sndio
      SDL2
      libevdev
      e2fsprogs
      libedit
      libpng

      # Математика и компрессия
      gmp
      nettle
      libtasn1
      p11-kit
      bzip2
      xz
      zstd
      brotli
      libffi

      # Прочее
      udev
      libnotify
    ];
  };
}
