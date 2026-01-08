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
            # Some buildGoModule configurations can produce an unexpected
            # binary name; normalize to $out/bin/smart-suggestion.
            if [ -e "$out/bin/cmd" ] && [ ! -e "$out/bin/smart-suggestion" ]; then
              mv "$out/bin/cmd" "$out/bin/smart-suggestion"
            fi

            install -Dm444 ${./smart-suggestion.plugin.zsh} \
              $out/share/zsh/plugins/smart-suggestion/smart-suggestion.plugin.zsh

            # The upstream plugin does not search $PATH; it looks for a
            # sibling binary named "smart-suggestion".
            ln -sf $out/bin/smart-suggestion \
              $out/share/zsh/plugins/smart-suggestion/smart-suggestion
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

            autoUpdate = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to enable smart-suggestion's automatic update checks (maps to SMART_SUGGESTION_AUTO_UPDATE).";
            };

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

            home.sessionVariables = lib.mkIf (cfg.environmentFile == null) (
              {
                SMART_SUGGESTION_AUTO_UPDATE = lib.mkDefault (lib.boolToString cfg.autoUpdate);
              }
              // cfg.environment
            );

            programs.zsh.initContent = lib.mkAfter ''
              ${lib.optionalString (cfg.environmentFile != null) ''
              if [ -f "${cfg.environmentFile}" ]; then
                set -a
                # shellcheck source=/dev/null
                . "${cfg.environmentFile}"
                set +a
              fi
              ''}

              # Disable auto-update by default (upstream default is true).
              (( ! ''${+SMART_SUGGESTION_AUTO_UPDATE} )) && export SMART_SUGGESTION_AUTO_UPDATE="${lib.boolToString cfg.autoUpdate}"

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
