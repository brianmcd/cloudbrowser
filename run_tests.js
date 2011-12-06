#!/usr/bin/env node

require('coffee-script');
process.env.TESTS_RUNNING = true;
var reporter = require('nodeunit').reporters.default;
reporter.run([
    'test/newbrowser.coffee',
    'test/newserver.coffee'
    /*
    'test',
    'test/api',
    'test/client',
    'test/server',
    'test/server/browser',
    'test/server/browser/dom',
    'test/shared'
    */
]);
