all:
	nix shell -c wasm32-wasi-cabal update
	nix shell -c wasm32-wasi-cabal install --installdir=. --install-method=copy --overwrite-policy=always
	nix shell -c wasm-opt -O cabal2json.wasm -o cabal2json.opt.wasm
