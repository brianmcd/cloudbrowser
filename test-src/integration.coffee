Path      = require('path')
FS        = require('fs')
TestCase  = require('nodeunit').testCase
Server    = require('../lib/server')

reqCache = require.cache
for entry of reqCache
    if /jsdom/.test(entry)
        delete reqCache[entry]

JSDOM = require('jsdom')

server = null
browsers = null

exports['tests'] =
    'setup' : (test) ->
        server = new Server(Path.join(__dirname, '..', 'test-src', 'files'))
        server.once 'ready', () ->
            browsers = server.browsers
            test.done()

    'basic test' : (test) ->
        browser = browsers.create('browser1',
                                  'http://localhost:3001/basic.html')
        client = browser.createTestClient()
        client.once 'loadFromSnapshot', () ->
            test.equal(client.document.getElementById('div1').innerHTML, 'Testing')
            test.done()

    # Loads a page that uses setTimeout, createElement, innerHTML, and
    # appendChild to create 20 nodes.
    'basic test2' : (test) ->
        browser = browsers.create('browser2',
                                  'http://localhost:3001/basic2.html')
        client = browser.createTestClient()
        client.once 'loadFromSnapshot', () ->
            browser.window.run("
                var count = 0;
                setTimeout(function insert () {
                    count++;
                    var div = document.getElementById('div1');
                    var child = document.createElement('div');
                    child.innerHTML = '' + count;
                    div.appendChild(child);
                    if (count != 21) {
                        setTimeout(insert, 0);
                    } else {
                        window.browser.testDone();
                    }
                }, 0);
            ")
            client.once 'testDone', () ->
                children = client.document.getElementById('div1').childNodes
                for i in [1..20]
                    test.equal(children[i-1].innerHTML, "#{i}")
                test.done()

    'iframe test1' : (test) ->
        browser = browsers.create('browser3',
                                  'http://localhost:3001/iframe-parent.html')
        client = browser.createTestClient()
        test.notEqual(browser, null)
        client.once 'loadFromSnapshot', () ->
            iframeElem = client.document.getElementById('testFrameID')
            test.notEqual(iframeElem, undefined)
            test.equal(iframeElem.getAttribute('src'), '')
            test.equal(iframeElem.getAttribute('name'), 'testFrame')
            iframeDoc = iframeElem.contentDocument
            test.notEqual(iframeDoc, undefined)
            iframeDiv = iframeDoc.getElementById('iframediv')
            test.notEqual(iframeDiv, undefined)
            test.equal(iframeDiv.className, 'testClass')
            test.equal(iframeDiv.innerHTML, 'Some text')
            browser.window.run("
                var iframe = document.getElementById('testFrameID');
                var iframeDoc = iframe.contentDocument;
                var iframeDiv = iframeDoc.getElementById('iframediv');
                iframeDiv.innerHTML = 'Set from outside';
                window.browser.testDone();
            ")
            client.once 'testDone', () ->
                test.equal(iframeDiv.innerHTML, 'Set from outside')
                test.done()

    'teardown' : (test) ->
        server.once 'close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        server.close()
