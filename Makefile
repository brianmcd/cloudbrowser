NPMDEPS = contextify jsdom html5

ALL: setup

.PHONY: submodules setup test jquery $(NPMDEPS)

submodules:
	git submodule update --init

$(NPMDEPS):
	rm -rf node_modules/$@
	npm install deps/$@

jquery: submodules
	cd deps/jquery-cloudbrowser && make update_submodules jquery min

setup: submodules $(NPMDEPS) jquery
	npm install

test:
	test/runner.js

build:
	rm -rf lib/
	node_modules/.bin/coffee -cb -o lib src

clean:
	rm -rf lib/
