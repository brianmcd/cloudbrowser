ALL: setup

.PHONY: submodules setup test jquery

submodules:
	git submodule update --init

jquery: submodules
	cd deps/jquery-cloudbrowser && make update_submodules jquery min

setup: jquery
	npm install

test:
	test/runner.js

build:
	rm -rf lib/
	node_modules/.bin/coffee -cb -o lib src

clean:
	rm -rf lib/
