{ pkgs, ... }: {
  home.username = "nix-test";
  home.homeDirectory = "/home/nix-test";
  home.stateVersion = "26.05";
  home.packages = [ pkgs.hello ];

  programs.home-manager.enable = true;
}
