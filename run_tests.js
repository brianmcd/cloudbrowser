#!/usr/bin/env node

process.env.TESTS_RUNNING = true;
var reporter = require('nodeunit').reporters.default;
reporter.run(['test', 'test/dom', 'test/browser']);
