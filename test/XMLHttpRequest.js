var FS      = require('fs'),
    Path    = require('path'),
    Server  = require('server'),
    Request = require('request'),
    Helpers = require('../test/helpers'),
    Browser = require('server/browser');

var server = null;
var jQuery = null;

// Info about the XHR target we'll use for most tests.
var targetPath = Path.join(__dirname, 'files', 'xhr-target.html');
var targetSource = FS.readFileSync(targetPath, 'utf8');

exports['setUp'] = function (test, assert) {
    server = new Server({
        app : '/',
        staticDir : Path.join(__dirname, 'files')
    });
    server.once('ready', function () {
        var jqPath = Path.resolve(__dirname, 'files', 'jquery-1.6.2.js');
        jQuery = FS.readFileSync(jqPath, 'utf8');
        test.finish();
    });
};

// Using the XMLHttpRequest object, make an AJAX request.
exports['test basic XHR'] = function (test, assert) {
    var window = Helpers.createEmptyWindow();
    window.test = test;
    window.assert = assert;
    window.targetSource = targetSource;
    window.run(
        "var xhr = new XMLHttpRequest();" +
        "console.log('just created an xhr');" +
        "xhr.open('GET', 'http://localhost:3001/xhr-target.html');" +
        "xhr.onreadystatechange = function () {" +
        "    if (xhr.readyState == 4) {" +
        "        console.log('TEST FINISHED');" +
        "        assert.equal(xhr.responseText, targetSource);" +
        "        test.finish();" +
        "    }" +
        "};" +
        "xhr.send();"
    );
};

// Using $.get, make an AJAX request.
exports['test jQuery XHR - absolute'] = function (test, assert) {
    var browser = new Browser('b', {}, function () {});
    browser.loadFromURL('http://localhost:3001/index.html');
    browser.once('PageLoaded', function () {
        var window = browser.window;
        window.test         = test;
        window.assert       = assert;
        window.targetSource = targetSource;
        window.run(jQuery);
        window.run( 
            "$.get('http://localhost:3001/xhr-target.html', function (data) {" +
            "    assert.equal(data, targetSource);" +
            "    test.finish();" +
            "});"
        );
    });
};

// Using $.get, make an AJAX request using a relative URL.
exports['test jQuery XHR - relative'] = function (test, assert) {
    var browser = new Browser('b', {}, function () {});
    browser.loadFromURL('http://localhost:3001/index.html');
    browser.once('PageLoaded', function () {
        var window = browser.window;
        window.test = test;
        window.assert = assert;
        window.targetSource = targetSource;
        window.run(jQuery);
        window.run(
            "$.get('/xhr-target.html', function (data) {" +
            "    assert.equal(data, targetSource);" +
            "    test.finish();" +
            "});");
    });
};

exports['tearDown'] = function (test, assert) {
    server.once('close', function () {
        test.finish();
    });
    server.close();
};
