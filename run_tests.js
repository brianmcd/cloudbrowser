#!/usr/bin/env node

process.env.TESTS_RUNNING = true;
var reporter = require('nodeunit').reporters.default;
reporter.run([
    'test',
    'test/api',
    'test/client',
    'test/server',
    'test/server/browser',
    'test/server/browser/dom',
    'test/shared'
]);
