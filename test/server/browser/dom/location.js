require('coffee-script');
var URL             = require('url'),
    LocationBuilder = require('../../../../lib/server/browser/location').LocationBuilder;

var lastEvent = null;

var MockBrowser = {
    window : {
        location : {},
        document : {
            createEvent : function () {
                return {
                    initEvent : function () {}
                };
            }
        },
        dispatchEvent : function () {
            lastEvent = 'hashchange'
        }
    },
    loadDOM : function () {
        lastEvent = 'pagechange';
    },
    loadFromURL : function () {
        lastEvent = 'pagechange';
    },
    setLocation : function (url) {
        this.window.location = URL.parse(url);
        var self = this;
        ['protocol', 'host', 'hostname',
         'port', 'pathname', 'search', 'hash'].forEach(function (prop) {
             self.window.location[prop] = self.window.location[prop] || ''
        });
    }
};

var Location = LocationBuilder(MockBrowser);

exports['test basic'] = function (test, assert) {
    var loc = new Location('http://www.google.com/awesome/page.html');
    assert.equal(loc.protocol, 'http:');
    assert.equal(loc.host, 'www.google.com');
    assert.equal(loc.hostname, 'www.google.com');
    assert.equal(loc.port, '');
    assert.equal(loc.pathname, '/awesome/page.html');
    assert.equal(loc.search, '');
    assert.equal(loc.hash, '');
    test.finish();
};

exports['test navigation'] = function (test, assert) {
    lastEvent = null;
    MockBrowser.setLocation('http://www.google.com');
    var loc = new Location('http://www.google.com/newpage.html');
    assert.equal(lastEvent, 'pagechange');
    lastEvent = null;
    
    MockBrowser.setLocation('http://www.site.com');
    loc = new Location('http://www.site.com');
    assert.equal(lastEvent, null);

    MockBrowser.setLocation('http://www.google.com');
    loc = new Location('http://www.google.com/#!update');
    assert.equal(lastEvent, 'hashchange');
    lastEvent = null;
    
    MockBrowser.setLocation('http://www.google.com');
    loc = new Location('http://www.google.com');
    assert.equal(lastEvent, null);

    loc.href = 'http://www.google.com/page2.html';
    assert.equal(lastEvent, 'pagechange');
    test.finish();
};

exports['test hashchange'] = function (test, assert) {
    lastEvent = null;
    // None of these tests should cause navigation, only hash changes.
    MockBrowser.setLocation('http://www.google.com');
    var loc = new Location('http://www.google.com');
    assert.equal(lastEvent, null);

    loc.href = 'http://www.google.com/#!/more/stuff';
    assert.equal(lastEvent, 'hashchange');
    lastEvent = null;

    MockBrowser.setLocation('http://www.google.com/#!/more/stuff');
    loc.href = 'http://www.google.com/#!/more/stuff';
    assert.equal(lastEvent, null);

    loc.href = 'http://www.google.com/#!changedagain';
    assert.equal(lastEvent, 'hashchange');
    test.finish();
};

// TODO: test navigating by setting properties like pathname
