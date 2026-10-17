# hypr/host.lua — мониторы и воркспейсы конкретной машины для Hyprland.
# Собирается из hosts/<хост>/host.nix; hyprland.lua подключает его через
# require("host") в самом начале, поэтому MONITOR1.., PRIMARY_MONITOR
# доступны и в binds.lua, и в windowrules.lua.
#
# Режимы мониторов отсюда — только стартовые: «Настройки → Экран» пишет
# свои в hypr/shell/monitors.lua, а тот подключается позже и перекрывает.
{
  lib,
  host,
  ...
}: let
  var = i: "MONITOR${toString (i + 1)}";

  monitorVars = lib.imap0 (i: m: ''${var i} = "${m.name}"'') host.monitors;

  monitorRules = map (m: let
    mode = m.mode or null;
  in
    if mode == null
    then ''hl.monitor({ output = "${m.name}", mode = "preferred", position = "auto", scale = "auto" })''
    else ''hl.monitor({ output = "${m.name}", mode = "${mode.mode}", position = "${mode.position}", scale = "${toString mode.scale}" })'')
  host.monitors;

  # default = true — «этот воркспейс открыт на мониторе по умолчанию».
  # Такой должен быть ровно один на монитор, поэтому он ставится только
  # первому воркспейсу из списка.
  workspaceRules = lib.concatLists (lib.imap0 (i: m:
    lib.imap0 (j: ws: ''hl.workspace_rule({ workspace = "${toString ws}", monitor = ${var i}${lib.optionalString (j == 0) ", default = true"}, persistent = true })'')
    m.workspaces)
  host.monitors);
in {
  xdg.configFile."hypr/host.lua".text = ''
    -- Сгенерировано из hosts/<хост>/host.nix. Править там, а не здесь.

    ${lib.concatStringsSep "\n" monitorVars}
    PRIMARY_MONITOR = MONITOR1

    ${lib.concatStringsSep "\n" monitorRules}

    ${lib.concatStringsSep "\n" workspaceRules}
  '';
}
