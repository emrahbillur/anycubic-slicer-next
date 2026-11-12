{
  description = "AnycubicSlicerNext - 3D printer slicer based on OrcaSlicer";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      anycubic-slicer-next = pkgs.callPackage ./default.nix {
        cgal = pkgs.cgal_5;
        src = pkgs.fetchFromGitHub {
          owner = "ANYCUBIC-3D";
          repo = "AnycubicSlicerNext";
          rev = "6103ed8b511609658d00d0538cc7f0609cdb57da";
          hash = "sha256-0kXjIoinNvpkHZ54qlTkQtk9DmMMJ27nr+nCjHKH7uk=";
        };
        libnoiseSrc = pkgs.fetchzip {
          url = "https://github.com/SoftFever/Orca-deps-libnoise/archive/refs/tags/1.0.zip";
          hash = "sha256-nzvtWsYz4REVcPRpKysOPOYIlMNhfbDHTkyS7PKvY+c=";
        };
      };
    in {
      packages.${system} = {
        default = anycubic-slicer-next;
        anycubic-slicer-next = anycubic-slicer-next;
      };
    };
}
