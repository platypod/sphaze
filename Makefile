.DEFAULT_GOAL := help

fmt:      ## Format all source (haxe-formatter)
	haxelib run formatter -s src -s test

fmt-check: ## Check formatting without modifying files (used by CI)
	haxelib run formatter -s src -s test --check

lint:     ## Lint (haxe-checkstyle)
	haxelib run checkstyle -s src -s test -c checkstyle.json --exitcode

check:    ## Compile check (haxe build.hxml)
	haxe build.hxml

test:     ## Run the utest suite
	haxe test.hxml
	node bin/test.js

build:    ## Production web build: bin/ becomes a self-contained static web root
	haxe build.hxml
	cp index.html bin/index.html

bake-geodesic: ## Regenerate the baked geodesic sphere data asset (res/geodesic/)
	haxe bake.hxml
	neko bin/bake.n

search-gliders: ## Run multi-rule glider search (B2/S34, B24/S46, B35/S2 comparison)
	haxe search.hxml
	neko bin/search.n

serve:    ## Build, then serve bin/ at http://localhost:8080 (Ctrl+C to stop)
	$(MAKE) build
	cd bin && python3 -m http.server 8080

help:     ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: fmt fmt-check lint check test build bake-geodesic search-gliders serve help
