EXTERNS=$(shell find node_modules/google-closure-compiler/contrib/nodejs -name '*.js' | sed 's/^/--externs=/')
JSEXE=result/bin/cabal2json.jsexe

all: cabal2json.min.js

$(JSEXE)/all.js: src cabal2json.cabal default.nix
	nix-build -A projectCross.ghcjs.hsPkgs.cabal2json.components.exes.cabal2json

cabal2json.min.js: $(JSEXE)/all.js
	closure-compiler $(JSEXE)/all.js --compilation_level=ADVANCED_OPTIMIZATIONS $(EXTERNS) --externs=$(JSEXE)/all.js.externs > cabal2json.min.js
