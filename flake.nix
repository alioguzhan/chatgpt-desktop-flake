{
  description = "ChatGPT Desktop packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = package: nixpkgs.lib.getName package == "chatgpt";
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          chatgpt = pkgs.callPackage ./package/package.nix { };
          updater = pkgs.writeShellApplication {
            name = "update-chatgpt";
            runtimeInputs = with pkgs; [
              coreutils
              curl
              diffutils
              gzip
              gnused
              jq
              nix
            ];
            text = ''
              export SOURCE_JSON="$PWD/package/source.json"
              if [[ ! -f "$SOURCE_JSON" ]]; then
                echo "Run this updater from the repository root" >&2
                exit 1
              fi
              exec ${pkgs.bash}/bin/bash ${./package/update.sh} "$@"
            '';
          };
        in
        {
          inherit chatgpt updater;
          default = chatgpt;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.chatgpt}/bin/chatgpt";
          meta.description = "Launch ChatGPT Desktop";
        };

        update = {
          type = "app";
          program = "${self.packages.${system}.updater}/bin/update-chatgpt";
          meta.description = "Update ChatGPT package metadata from the official repository";
        };
      });
    };
}
