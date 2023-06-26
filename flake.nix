{
  inputs.ghc-wasm-meta.url = "git+https://gitlab.haskell.org/ghc/ghc-wasm-meta.git";
  outputs = { ghc-wasm-meta, ... }: let
      pkg = ghc-wasm-meta.packages.x86_64-linux;
    in {
      packages.x86_64-linux.default = pkg.all_9_6;
    };
}
