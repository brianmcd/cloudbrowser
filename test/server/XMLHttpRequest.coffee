FS      = require('fs')
Path    = require('path')
Request = require('request')
Helpers = require('../helpers')
Browser = require('../../src/server/browser')

server = null
jQuery = null

# Info about the XHR target we'll use for most tests.
targetPath = Path.join(__dirname, '..', 'files', 'xhr-target.html')
targetSource = FS.readFileSync(targetPath, 'utf8')

jqPath = Path.resolve(__dirname, '..', 'files', 'jquery-1.6.2.js')
jQuery = FS.readFileSync(jqPath, 'utf8')

# Using the XMLHttpRequest object, make an AJAX request.
exports['test basic XHR'] = (test) ->
    browser = new Browser 'b', global.defaultApp
    browser.once 'PageLoaded', () ->
        window = browser.window
        window.test = test
        window.targetSource = targetSource
        window.run "
            var xhr = new XMLHttpRequest();
            xhr.open('GET', 'xhr-target.html');
            xhr.onreadystatechange = function () {
                if (xhr.readyState == 4) {
                    test.equal(xhr.responseText, targetSource);
                    test.done();
                }
            };
            xhr.send();"

# Using $.get, make an AJAX request.
exports['test jQuery XHR - absolute'] = (test) ->
    browser = new Browser 'b', global.defaultApp
    browser.once 'PageLoaded', () ->
        window = browser.window
        window.test = test
        window.targetSource = targetSource
        window.run(jQuery)
        window.run "
            $.get('http://localhost:3001/test/files/xhr-target.html', function (data) {
                test.equal(data, targetSource);
                test.done();
            });"

# Using $.get, make an AJAX request using a relative URL.
exports['test jQuery XHR - relative'] = (test) ->
    browser = new Browser 'b', global.defaultApp
    browser.once 'PageLoaded', () ->
        window = browser.window
        window.test = test
        window.targetSource = targetSource
        window.run(jQuery)
        window.run "
            $.get('xhr-target.html', function (data) {
                test.equal(data, targetSource);
                test.done();
            });"
