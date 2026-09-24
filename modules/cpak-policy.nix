# Общая политика для ВСЕХ приложений cpak: хостовый диалог выбора файлов.
#
# Почему не одной настройкой: у cpak нет «глобального override» — это
# сознательное решение его модели безопасности: чего нет в манифесте, того
# нельзя, и право filePicker по умолчанию выключено. Без него приложение
# рисует свой диалог ВНУТРИ контейнера и видит только файлы контейнера.
#
# Почему не файлами из home-manager: cpak читает override только если это
# настоящий файл, принадлежащий пользователю. Симлинк в /nix/store он
# отвергнет. Поэтому политика описана здесь, в Nix, а применяет её
# штатной командой `cpak override` маленький сервис:
#   - при входе в сессию;
#   - каждый раз, когда меняется набор установленных приложений
#     (установка, обновление, удаление) — через path-юнит.
# Обновление приложения — это новая версия, у неё новый каталог override,
# так что без path-юнита политика слетала бы после каждого апдейта.
{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  cpakBin = "${osConfig.services.cpak.package}/bin/cpak";

  # Что получает каждое приложение.
  # persistent — cpak предложит запомнить выданный доступ к файлу/папке,
  # чтобы не спрашивать при каждом запуске.
  filePicker = {
    openFile = true;
    openFolder = true;
    saveFile = true;
    persistent = true;
  };

  # GTK3 cpak переводит на портал сам (GTK_USE_PORTAL=1), как только у
  # приложения есть filePicker. Qt и GTK4 так не умеют — им нужны эти
  # переменные. Сливаются с env приложения, а не затирают его.
  env = [
    "QT_QPA_PLATFORMTHEME=xdgdesktopportal"
    "GDK_DEBUG=portals"
  ];

  applyPolicy = pkgs.writeShellApplication {
    name = "cpak-desktop-policy";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    # SC2016: $-переменные внутри одинарных кавычек — это переменные jq,
    # а не шелла, так и задумано.
    excludeShellChecks = ["SC2016"];
    text = ''
      want_picker='${builtins.toJSON filePicker}'
      want_env='${builtins.toJSON env}'

      if ! apps=$(${cpakBin} list --json 2>/dev/null); then
        echo "cpak-desktop-policy: cpak list не отработал, пропускаю" >&2
        exit 0
      fi
      [ -n "$apps" ] || exit 0

      jq -r '.[]? | [.origin, .version] | @tsv' <<<"$apps" |
        while IFS=$'\t' read -r origin version; do
          [ -n "$origin" ] || continue
          file="$HOME/.config/cpak/overrides/$origin/$version/cpak.json"

          # 1. filePicker. Если пользовательского override ещё нет, команда
          #    берёт за основу манифест и создаёт файл — поэтому при
          #    отсутствии файла вызываем её в любом случае: дальше env
          #    читается уже из файла, вместе с env самого манифеста.
          current='{}'
          [ -f "$file" ] && current=$(jq -c '.filePicker // {}' "$file")
          satisfied=$(jq --argjson want "$want_picker" \
            '. as $cur | $want | to_entries | all(.value == ($cur[.key] // false))' <<<"$current")

          if [ ! -f "$file" ] || [ "$satisfied" != "true" ]; then
            merged=$(jq -c --argjson want "$want_picker" '. + $want' <<<"$current")
            if ! ${cpakBin} override "$origin" -k filePicker -v "$merged"; then
              echo "cpak-desktop-policy: $origin — filePicker не применился (потолок политики cpak?)" >&2
              continue
            fi
          fi

          # 2. env: наши переменные заменяют одноимённые, остальные остаются.
          [ -f "$file" ] || continue
          current_env=$(jq -c '.env // []' "$file")
          merged_env=$(jq -c --argjson add "$want_env" '
            ($add | map(split("=")[0])) as $keys
            | [ .[] | select((split("=")[0]) as $k | ($keys | index($k)) | not) ] + $add
          ' <<<"$current_env")

          if [ "$merged_env" != "$current_env" ]; then
            ${cpakBin} override "$origin" -k env -v "$merged_env" ||
              echo "cpak-desktop-policy: $origin — env не применился" >&2
          fi
        done
    '';
  };
in {
  systemd.user.services.cpak-desktop-policy = {
    Unit.Description = "Хостовый диалог выбора файлов для всех приложений cpak";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe applyPolicy;
    };
    Install.WantedBy = ["default.target"];
  };

  # Срабатывает на установку, обновление и удаление приложений.
  # Скрипт идемпотентный: если политика уже выполнена, он ничего не пишет,
  # так что собственные записи cpak при enrol не зацикливают его.
  systemd.user.paths.cpak-desktop-policy = {
    Unit.Description = "Следить за набором приложений cpak";
    Path = {
      PathChanged = [
        "%h/.local/share/cpak/manifests"
        "%h/.local/share/cpak/store"
      ];
      Unit = "cpak-desktop-policy.service";
    };
    Install.WantedBy = ["default.target"];
  };
}
