# nix-ld: запуск сторонних динамически слинкованных бинарников,
# рассчитанных на FHS-систему.
#
# После отказа от враппера AppImage этот список стал ОСНОВНЫМ и
# единственным рычагом совместимости: именно отсюда образы берут всё,
# чего не принесли с собой. Если приложение падает с
#   error while loading shared libraries: libчтото.so.N
# то ищешь пакет через `nix-locate libчтото.so.N` (nix-index-database
# подключён в flake.nix) и дописываешь его сюда. Это ровно тот же цикл,
# что `pacman -S` на Arch, только с пересборкой и перезаходом в сессию —
# NIX_LD_LIBRARY_PATH подхватывается при старте сессии.
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
      fuse # нужен рантайму AppImage (libfuse.so.2)
      fuse3
      icu
      libuuid
      libxml2
      libsecret
      harfbuzz
      freetype
      fontconfig
      fribidi
      libgcrypt
      libgpg-error
      keyutils.lib
      curl

      # Графика и UI-тулкиты
      mesa
      libgbm # Electron/Chromium: libgbm.so.1, отделён от mesa
      libGL
      libGLU
      libepoxy
      libdrm
      libva
      vulkan-loader
      gtk3
      gtk4
      libadwaita
      pango
      cairo
      atk
      at-spi2-atk
      gdk-pixbuf
      glib
      pciutils

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
      libsm
      libice

      # Хелперы xcb. Их dlopen'ит платформенный плагин `xcb` из Qt —
      # в том числе Qt, который образ принёс с собой. Без них вылезает
      # классическое "Could not load the Qt platform plugin xcb".
      # Сам Qt сюда класть НЕ надо: почти все образы несут его внутри,
      # а хостовый libQt6Core из LD_LIBRARY_PATH даст конфликт версий.
      # Если Qt-образ всё же чудит — попробуй `env -u QT_PLUGIN_PATH ./образ`.
      libxcb-util
      libxcb-wm
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-cursor

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
      libjpeg
      libtiff

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
