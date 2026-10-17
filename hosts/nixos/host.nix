# Всё, что отличает ЭТУ машину от любой другой. Имя хоста — это имя
# папки: hosts/nixos → networking.hostName = "nixos" и
# nixos-rebuild switch --flake .#nixos.
#
# Файл — просто данные, без опций NixOS. Модули получают его как `host`
# (так же, как `appearance` из flake.nix) и сами решают, что с ним делать.
{
  # Мониторы. Первый в списке — ОСНОВНОЙ: на него идут игры, лаунчеры,
  # .exe и запись экрана (ALT+F9/F10).
  #   name       — имя выхода, как в `hyprctl monitors`;
  #   workspaces — какие воркспейсы живут на мониторе, первый из них
  #                открывается по умолчанию;
  #   mode       — режим по умолчанию: { mode, position, scale } в синтаксисе
  #                hl.monitor; null — «preferred, auto».
  # Это только стартовые значения: в сессии разрешение, частоту, масштаб
  # и расположение меняют в «Настройки → Экран», и они перекрывают эти.
  monitors = [
    {
      name = "HDMI-A-1"; # LG Ultrawide
      workspaces = [1 2 3 4 5];
      mode = {
        mode = "2560x1080@100";
        position = "0x0";
        scale = 1;
      };
    }
    {
      name = "HDMI-A-2"; # Acer
      workspaces = [6 7 8 9];
      mode = null;
    }
  ];

  # Видеокарта AMD: ранняя загрузка amdgpu (без серого экрана при старте),
  # разблокированный разгон (ppfeaturemask) и служба LACT.
  amdGpu = true;

  # Андервольт Ryzen через ryzen_smu (scripts/ruv.py): число ядер и
  # смещение Curve Optimizer. null — андервольта нет.
  # Смещение подбирается под конкретный процессор: чужие −25 могут
  # дать нестабильность. Проверять стресс-тестом (например, OCCT/y-cruncher).
  undervolt = {
    cores = 8;
    offset = -25;
  };
}
