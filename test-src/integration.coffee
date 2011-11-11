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

# TODO: a test with dynamically appended iframes
exports['tests'] =
    'setup' : (test) ->
        server = new Server
            appPath : '/'
            staticDir : Path.join(__dirname, '..', 'test-src', 'files')
        server.once 'ready', () ->
            browsers = server.browsers
            test.done()

    'basic test' : (test) ->
        browser = browsers.create
            id : 'browser1'
            url : 'http://localhost:3001/basic.html'
        client = browser.createTestClient()
        client.once 'loadFromSnapshot', () ->
            test.equal(client.document.getElementById('div1').innerHTML, 'Testing')
            client.disconnect()
            test.done()

    # Loads a page that uses setTimeout, createElement, innerHTML, and
    # appendChild to create 20 nodes.
    'basic test2' : (test) ->
        browser = browsers.create
            id : 'browser2'
            url : 'http://localhost:3001/basic2.html'
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
                client.disconnect()
                test.done()

    'iframe test1' : (test) ->
        browser = browsers.create
            id : 'browser3'
            url : 'http://localhost:3001/iframe-parent.html'
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
                client.disconnect()
                test.done()

    'event inference via advice' : (test) ->
        browser = browsers.create
            id : 'browser4'
            url : 'http://localhost:3001/event_inference_advice.html'
        client = browser.createTestClient()
        browser.window.testClient = client
        test.notEqual(browser, null)
        test.notEqual(client, null)
        client.once 'loadFromSnapshot', () ->
            browser.window.test = test
            # Register 3 event listeners in the server's DOM. After the client
            # receives the signal from the server an registers on an event, we
            # generate a synthetic instance of that event and dispatch it into
            # the client's DOM.  This should cause the client to send the event
            # to the server.  We stop the test after all 3 events have been
            # registered on the server, registered on the client, sent into
            # the client's DOM, and received at the server.
            browser.window.run("
                var count = 0;
                var div = document.getElementById('div1');
                var p = document.getElementById('p1');
                var textarea = document.getElementById('textarea1');
                div.addEventListener('click', function (event) {
                    count++;
                    test.equal(event.target, div);
                });
                p.addEventListener('focus', function (event) {
                    count++;
                    test.equal(event.target, p);
                });
                textarea.addEventListener('change', function (event) {
                    count++;
                    test.equal(event.target, textarea);
                    test.equal(count, 3);
                    testClient.disconnect();
                    test.done();
                });
            ")
            # Once the client registers the event listener for a particular
            # event, we fire it on the client, which should cause it to be
            # sent to the server.
            doc = client.document
            eventFirers =
                'click' : () ->
                    div = doc.getElementById('div1')
                    click = doc.createEvent('MouseEvents')
                    click.initMouseEvent('click', false, true, client.window)
                    div.dispatchEvent(click)
                'focus' : () ->
                    p = doc.getElementById('p1')
                    focus = doc.createEvent('HTMLEvents')
                    focus.initEvent('focus', false, true)
                    p.dispatchEvent(focus)
                'change' : () ->
                    textarea = doc.getElementById('textarea1')
                    change = doc.createEvent('HTMLEvents')
                    change.initEvent('change', false, true)
                    textarea.dispatchEvent(change)

            client.on 'addEventListener', (params) ->
                eventFirers[params.type]()

    # This test is similar to the one above, except that we make sure the
    # listeners are registered before the client is sent its snapshot. We do
    # this by putting the script inline at the bottom of the body.  When the
    # client fires 'loadFromSnapshot', the listeners should be installed.
    'event inference via snapshot' : (test) ->
        browser = browsers.create
            id : 'browser5'
            url : 'http://localhost:3001/event_inference_snapshot.html'
        client = browser.createTestClient()
        browser.window.testClient = client
        test.notEqual(browser, null)
        test.notEqual(client, null)
        client.once 'loadFromSnapshot', () ->
            # NOTE: The code in the script running on the server DOM will end
            # the test once all 3 events have been received.
            browser.window.test = test

            doc = client.document
            # Fire the 3 events on the client DOM.
            div = doc.getElementById('div1')
            click = doc.createEvent('MouseEvents')
            click.initMouseEvent('click', false, true, client.window)
            div.dispatchEvent(click)

            p = doc.getElementById('p1')
            focus = doc.createEvent('HTMLEvents')
            focus.initEvent('focus', false, true)
            p.dispatchEvent(focus)

            textarea = doc.getElementById('textarea1')
            change = doc.createEvent('HTMLEvents')
            change.initEvent('change', false, true)
            textarea.dispatchEvent(change)

    'teardown' : (test) ->
        server.once 'close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        server.close()
