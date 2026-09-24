# btop — единственный системный монитор (вместо Mission Center).
# Открывается выезжающим воркспейсом на SUPER+M / SUPER+SHIFT+Esc /
# Ctrl+Shift+Esc, см. binds.lua и windowrules.lua.
{pkgs, ...}: {
  programs.btop = {
    enable = true;

    # Графики видеокарты AMD: btop читает их через rocm-smi. Без этой
    # сборки блока GPU просто нет.
    package = pkgs.btop.override {rocmSupport = true;};

    settings = {
      # Тема из комплекта btop. Сменить на лету: Esc → Options → Color theme,
      # но после пересборки вернётся эта.
      color_theme = "adwaita-dark";
      # Прозрачный фон — видно размытие, как у остальных окон.
      theme_background = false;
      rounded_corners = true;

      # Процессор, видеокарта отдельным блоком, память с дисками, сеть и
      # процессы. Места хватает: btop открывается на весь экран, шрифт 12.
      shown_boxes = "cpu gpu0 mem net proc";
      # Строка GPU в блоке процессора — только когда отдельного блока нет.
      show_gpu_info = "Auto";
      update_ms = 1000;
      proc_sorting = "cpu lazy";
      proc_tree = false;
    };
  };
}
