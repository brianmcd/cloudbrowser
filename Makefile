NPMDEPS = contextify jsdom html5

ALL: setup

.PHONY: submodules setup test jquery socket.io-client $(NPMDEPS)

submodules:
	git submodule update --init

$(NPMDEPS):
	rm -rf node_modules/$@
	npm install deps/$@

jquery: submodules
	cd deps/jquery-cloudbrowser && make update_submodules jquery min

socket.io-client: submodules
	cd deps/socket.io-client && npm installi --production true

setup: submodules $(NPMDEPS) jquery socket.io-client
	npm install

test:
	./run_tests.js

build:
	rm -rf lib/
	node_modules/.bin/coffee -cwb -o lib src

clean:
	rm -rf lib/
