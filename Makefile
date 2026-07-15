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

help:     ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: fmt fmt-check lint check test build help
