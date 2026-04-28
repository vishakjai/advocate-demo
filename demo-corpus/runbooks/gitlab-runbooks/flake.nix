{
  description = "GitLab Runbooks";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    mise2nix = {
      url = "gitlab:nolith/mise2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        (
          { inputs, ... }:
          {
            perSystem =
              { system, ... }:
              {
                _module.args = {
                  pkgs = import inputs.nixpkgs {
                    inherit system;
                    overlays = [
                      inputs.mise2nix.overlays.default
                      inputs.mise2nix.overlays.gitlab-tools
                    ];
                    config.allowUnfree = true;
                  };
                };
              };
          }
        )
        inputs.mise2nix.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
      ];

      perSystem =
        { pkgs, mise2nix, ... }:
        {
          devShells.default = pkgs.mkShellNoCC {
            env = {
              # set true to suppress verboseToolsList output
              MISE2NIX_QUIET = false;
            };

            packages = mise2nix.buildInputs;
            shellHook = mise2nix.verboseToolsList;
          };

          # source code formatter
          treefmt = {
            programs = {
              # add additional formatters here from https://github.com/numtide/treefmt-nix?tab=readme-ov-file#supported-programs
              nixfmt.enable = true;
            };
          };
        };
    };
}
