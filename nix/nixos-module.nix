# NixOS module for Lniri
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.lniri;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.programs.lniri = {
    enable = lib.mkEnableOption "Lniri, scrollable-tiling Wayland compositor with liquid glass effects";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.lniri;
      defaultText = lib.literalExpression "lniri.packages.\${system}.lniri";
      description = "The Lniri package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = cfg.package;
    };
  };
}
