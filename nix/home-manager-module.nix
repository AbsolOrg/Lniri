# home-manager module for Lniri
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
      description = "The Lniri package to install.";
    };

    config = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.lines lib.types.path);
      default = null;
      example = lib.literalExpression "builtins.readFile ./config.kdl";
      description = ''
        Contents of `~/.config/lniri/config.kdl`. Either inline KDL text or a
        path to a config file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."lniri/config.kdl" = lib.mkIf (cfg.config != null) (
      if builtins.isPath cfg.config || lib.isStorePath cfg.config then
        { source = cfg.config; }
      else
        { text = cfg.config; }
    );
  };
}
