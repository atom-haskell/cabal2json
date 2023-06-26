all:
	nix shell -c wasm32-wasi-cabal install --installdir=. --install-method=copy --overwrite-policy=always
