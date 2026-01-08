{
  description = "Smart Suggestion (Zsh plugin + Go binary) dev shell and Home Manager module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      lib = pkgs.lib;
      version = "dev";
    in
    {
      packages.${system} = {
        smart-suggestion = pkgs.buildGoModule {
          pname = "smart-suggestion";
          inherit version;

          src = self;

          subPackages = [ "cmd/smart-suggestion" ];

          # Fill this by running `nix build` once; Nix will suggest the correct hash.
          vendorHash = "sha256-VDNDlU0zug+2ZJSvaWHI905nmDnlkfPY4KNMq9wGvME=";

          ldflags = [
            "-s" "-w"
            "-X" "main.Version=${version}"
          ];

          postInstall = ''
            install -Dm444 ${./smart-suggestion.plugin.zsh} \
              $out/share/zsh/plugins/smart-suggestion/smart-suggestion.plugin.zsh
          '';

          meta = with lib; {
            description = "AI-powered smart suggestions for zsh";
            platforms = [ system ];
          };
        };

        default = self.packages.${system}.smart-suggestion;
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.smart-suggestion}/bin/smart-suggestion";
      };

      homeManagerModules.smart-suggestion = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.smart-suggestion;
        in
        {
          options.programs.smart-suggestion = {
            enable = lib.mkEnableOption "Smart Suggestion zsh plugin";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.smart-suggestion;
              description = "Package to use for Smart Suggestion";
            };

            environment = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = {};
              description = "Environment variables exported for Smart Suggestion";
            };

            environmentFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional path to a shell-compatible env file to source before loading the plugin";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];

            home.sessionVariables = lib.mkIf (cfg.environmentFile == null && cfg.environment != {}) cfg.environment;

            programs.zsh.initExtra = lib.mkAfter ''
              ${lib.optionalString (cfg.environmentFile != null) ''
              if [ -f "${cfg.environmentFile}" ]; then
                set -a
                # shellcheck source=/dev/null
                . "${cfg.environmentFile}"
                set +a
              fi
              ''}

              source ${cfg.package}/share/zsh/plugins/smart-suggestion/smart-suggestion.plugin.zsh
            '';
          };
        };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go
          zsh
        ];
      };
    };
}
