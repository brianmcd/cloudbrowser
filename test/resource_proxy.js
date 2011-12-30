require('coffee-script');
var Path          = require('path'),
    FS            = require('fs'),
    Server        = require('server'),
    ResourceProxy = require('server/resource_proxy');

exports['test basic'] = function (test, assert) {
    var proxy = new ResourceProxy('http://www.google.com');
    assert.notEqual(proxy, null);
    assert.equal(proxy.urlsByIndex.length, 0);
    assert.equal(Object.keys(proxy.urlsByName).length, 0);
    test.finish();
};

exports['test absolute urls'] = function (test, assert) {
    var proxy = new ResourceProxy('http://www.google.com');
    assert.notEqual(proxy, null);
    var idx = proxy.addURL('http://www.vt.edu');
    assert.equal(idx, 0);
    assert.equal(proxy.urlsByIndex[idx].href, 'http://www.vt.edu/');
    idx = proxy.addURL('http://news.ycombinator.com');
    assert.equal(idx, 1);
    assert.equal(proxy.urlsByIndex[idx].href, 'http://news.ycombinator.com/');
    test.finish();
};

exports['test relative urls'] = function (test, assert) {
    var proxy = new ResourceProxy('http://www.google.com');
    assert.notEqual(proxy, null);
    var idx = proxy.addURL('/index.html');
    assert.equal(idx, 0);
    assert.equal(proxy.urlsByIndex[idx].href,
               'http://www.google.com/index.html');

    var proxy2 = new ResourceProxy('http://www.google.com/test/index.html');
    assert.notEqual(proxy2, null);
    idx = proxy2.addURL('new.html');
    assert.equal(idx, 0);
    assert.equal(proxy2.urlsByIndex[idx].href,
              'http://www.google.com/test/new.html');
    idx = proxy2.addURL('/new.html');
    assert.equal(idx, 1);
    assert.equal(proxy2.urlsByIndex[idx].href,
              'http://www.google.com/new.html');
    idx = proxy2.addURL('../index.html');
    assert.equal(idx, 2);
    assert.equal(proxy2.urlsByIndex[idx].href,
               'http://www.google.com/index.html');
    test.finish();
};

exports['test fetch'] = function (test, assert) {
    var filesPath = Path.join(__dirname, 'files');
    var server = new Server({
        app : '/',
        staticDir : filesPath
    });
    // mock response obejct
    function Response (expected) {
        this.expected = expected;
        this.current = "";
    }
    Response.prototype = {
        write : function (data) {
            this.current += data;
        },
        writeHead : function () {},
        end : function () {
            assert.equal(this.current, this.expected)
            server.once('close', function () {
                test.finish();
            });
            server.close();
        }
    };

    var proxy = new ResourceProxy('http://localhost:3001');
    assert.notEqual(proxy, null);
    var idx = proxy.addURL('/xhr-target.html');
    assert.equal(idx, 0);
    assert.equal(proxy.urlsByIndex[idx].href,
               'http://localhost:3001/xhr-target.html');
    var targetPath = Path.join(__dirname, 'files', 'xhr-target.html');
    var targetSource = FS.readFileSync(targetPath, 'utf8');
    var res = new Response(targetSource);

    server.once('ready', function () {
        proxy.fetch(idx, res);
    });
};
