# pixel-quickshare — служба Quick Share (src/main.rs) на rqs_lib из
# open-quickshare. Лицензия GPL-3.0-or-later, как у rqs_lib.
# Подключается в modules/system/quickshare.nix.
{
  lib,
  rustPlatform,
  pkg-config,
  protobuf,
  dbus,
  makeWrapper,
  libnotify,
  wl-clipboard,
  xdg-utils,
  networkmanager,
}:
rustPlatform.buildRustPackage {
  pname = "pixel-quickshare";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src];
  };
  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "rqs_lib-0.11.5" = "sha256-R9EjmDVchXXVIoDdHtoShT42lKUS/+b+CD0mlQ9Q6S4=";
      "mdns-sd-0.10.4" = "sha256-y8pHtG7JCJvmWCDlWuJWJDbCGOheD4PN+WmOxnakbE4=";
      "sys_metrics-0.2.7" = "sha256-hCialGTBTA7QdiqlTV6sBdiXpgDEB+96IWLFV2M+36o=";
    };
  };

  nativeBuildInputs = [pkg-config protobuf makeWrapper];
  buildInputs = [dbus];

  # уведомления согласия, буфер обмена, «Открыть папку»; nmcli — Wi-Fi Direct
  # и точка доступа в rqs_lib
  postInstall = ''
    wrapProgram $out/bin/pixel-quickshare \
      --suffix PATH : ${lib.makeBinPath [libnotify wl-clipboard xdg-utils networkmanager]}
  '';

  meta = {
    description = "Quick Share с Android для Pixel Shell";
    license = lib.licenses.gpl3Plus;
    mainProgram = "pixel-quickshare";
  };
}
