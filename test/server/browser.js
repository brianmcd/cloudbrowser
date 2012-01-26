var Path    = require('path'),
    Server  = require('server'),
    Browser = require('server/browser');

var server   = null;
var browsers = null;

exports['setUp'] = function (test, assert) {
    server = new Server({
        app : '/',
        staticDir : Path.join(__dirname, 'files')
    });
    server.once('ready', function () {
        browsers = server.browsers;
        test.finish();
    });
};

exports['test basic'] = function (test, assert) {
    var count = 0;
    var events = [
        {type : 'DOMNodeInsertedIntoDocument'},
        {type : 'DOMAttrModified'},
        {type : 'DOMNodeRemovedFromDocument'},
        {type : 'DOMNodeRemovedFromDocument'}
    ];
    function handleEvent (type, event) {
        assert.equal(type, events[count].type);
        if (++count == events.length) {
            test.finish();
        }
    }
    var browser = new Browser('browser1');
    browser.loadFromURL('http://localhost:3001/blank.html');
    browser.once('PageLoaded', function () {
        ['DOMNodeInsertedIntoDocument',
         'DOMNodeRemovedFromDocument',
         'DOMAttrModified'].forEach(function (type) {
            browser.on(type, function (event) {
                handleEvent(type, event);
            });
        });
        var doc = browser.window.document;
        var div = doc.createElement('div');
        var div2 = doc.createElement('div');
        div.appendChild(div2);
        doc.body.appendChild(div);
        div.align = 'center';
        div.removeChild(div2);
        doc.body.removeChild(div);
    });
};

exports['tearDown'] = function (test, assert) {
    server.once('close', function () {
        var reqCache = require.cache;
        for (var p in reqCache) {
            if (/jsdom/.test(p)) {
                delete reqCache[p];
            }
        }
        test.finish()
    });
    server.close()
};
