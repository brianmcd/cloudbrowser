{createRemoteBrowserServer} = require('./helpers')
# TODO: a test with dynamically appended iframes

exports['basic test'] = (test) ->
    b = createRemoteBrowserServer('http://localhost:3001/test/files/basic.html')
    client = b.createTestClient()
    client.once 'PageLoaded', () ->
        test.equal(client.document.getElementById('div1').innerHTML, 'Testing')
        client.disconnect()
        b.close()
        test.done()

# Loads a page that uses setTimeout, createElement, innerHTML, and
# appendChild to create 20 nodes.
exports['basic test2'] = (test) ->
    b = createRemoteBrowserServer('http://localhost:3001/test/files/basic2.html')
    browser = b.browser
    client = b.createTestClient()
    client.once 'PageLoaded', () ->
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
        client.once 'TestDone', () ->
            children = client.document.getElementById('div1').childNodes
            for i in [1..20]
                test.equal(children[i-1].innerHTML, "#{i}")
            client.disconnect()
            test.done()

exports['iframe test1'] = (test) ->
    b = createRemoteBrowserServer('http://localhost:3001/test/files/iframe-parent.html')
    client = b.createTestClient()
    browser = b.browser
    client.once 'PageLoaded', () ->
        iframeElem = client.document.getElementById('testFrameID')
        test.notEqual(iframeElem, null)
        test.equal(iframeElem.getAttribute('src'), null)
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
        client.once 'TestDone', () ->
            test.equal(iframeDiv.innerHTML, 'Set from outside')
            client.disconnect()
            test.done()

exports['event inference via advice'] = (test) ->
    b = createRemoteBrowserServer('http://localhost:3001/test/files/event_inference_advice.html')
    client = b.createTestClient()
    browser = b.browser
    client.once 'PageLoaded', () ->
        # Remember, we automatically set this in the CLIENT'S DOM, but we need
        # access to it server-side, so need to set it explicitly.
        browser.window.testClient = client
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
            });")
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

        # Only 'focus' should emit an event, since it isn't a default event.
        client.once 'AddEventListener', (args) ->
            type = args[0]
            test.equal(type, 'focus')
            eventFirers['click']()
            eventFirers['focus']()
            eventFirers['change']()

# This test is similar to the one above, except that we make sure the
# listeners are registered before the client is sent its snapshot. We do
# this by putting the script inline at the bottom of the body.  When the
# client fires 'loadFromSnapshot', the listeners should be installed.
exports['event inference via snapshot'] = (test) ->
    b = createRemoteBrowserServer('http://localhost:3001/test/files/event_inference_snapshot.html')
    client = b.createTestClient()
    browser = b.browser
    client.once 'PageLoaded', () ->
        browser.window.testClient = client
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
