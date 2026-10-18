{ 
    pkgs ? import <nixpkgs> {  },
}:
pkgs.mkShell {
    buildInputs = with pkgs; [
        odin
        sdl3
    ];
}

