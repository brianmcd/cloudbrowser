Path      = require('path')
FS        = require('fs')
TestCase  = require('nodeunit').testCase
Server    = require('../lib/server')
bootstrap = require('../lib/client/dnode_client')

reqCache = require.cache
for entry of reqCache
    if /jsdom/.test(entry)
        delete reqCache[entry]

JSDOM = require('jsdom')

server = null

initTest = (browserID, url) ->
    browser = server.browsers.create(browserID, url)
    return browser.createTestClient()

checkReady = (window, callback) ->
    if window.document.getElementById('finished')?.innerHTML == 'true'
        callback()
    else
        setTimeout(checkReady, 0, window, callback)

exports['tests'] =
    'setup' : (test) ->
        server = new Server(Path.join(__dirname, '..', 'test-src', 'files'))
        server.once('ready', () -> test.done())

    'basic test' : (test) ->
        window = initTest('browser1', 'http://localhost:3001/basic.html')
        document = window.document
        tests = () ->
            test.equal(document.getElementById('div1').innerHTML, 'Testing')
            test.done()
        checkReady(window, tests)

    # Loads a page that uses setTimeout, createElement, innerHTML, and
    # appendChild to create 20 nodes.
    'basic test2' : (test) ->
        window = initTest('browser2', 'http://localhost:3001/basic2.html')
        document = window.document
        tests = () ->
            children = document.getElementById('div1').childNodes
            for i in [1..20]
                test.equal(children[i-1].innerHTML, "#{i}")
            test.done()
        checkReady(window, tests)

    'iframe test1' : (test) ->
        window = initTest('browser3', 'http://localhost:3001/iframe-parent.html')
        document = window.document
        browser = server.browsers.find('browser3')
        test.notEqual(browser, null)
        tests = () ->
            iframeElem = document.getElementById('testFrameID')
            test.notEqual(iframeElem, undefined)
            test.equal(iframeElem.getAttribute('src'), '')
            test.equal(iframeElem.getAttribute('name'), 'testFrame')
            iframeDoc = iframeElem.contentDocument
            test.notEqual(iframeDoc, undefined)
            iframeDiv = iframeDoc.getElementById('iframediv')
            test.notEqual(iframeDiv, undefined)
            test.equal(iframeDiv.className, 'testClass')
            test.equal(iframeDiv.innerHTML, 'Some text')
            document.getElementById('finished').childNodes[0].value = 'false'
            browser.window.NEXT = true
            moreTests = () ->
               test.equal(iframeDiv.innerHTML, 'Set from outside')
               test.done()
            checkReady(window, moreTests)
        checkReady(window, tests)

    # Using the XMLHttpRequest object, make an AJAX request.
    'basic XHR' : (test) ->
        clientWindow = initTest('browser4', 'http://localhost:3001/xhr-basic.html')
        browser = server.browsers.find('browser4')
        window = browser.window
        document = window.document
        tests = () ->
            targetPath = Path.join(__dirname, '..', 'test-src', 'files', 'xhr-target.html')
            targetSource = FS.readFileSync(targetPath, 'utf8')
            test.equal(window.responseText, targetSource)
            test.done()
        checkReady(clientWindow, tests)
        
    # Using $.get, make an AJAX request.
    'jQuery XHR - absolute' : (test) ->
        clientWindow = initTest('browser5', 'http://localhost:3001/xhr-jquery.html')
        browser = server.browsers.find('browser5')
        window = browser.window
        document = window.document
        tests = () ->
            targetPath = Path.join(__dirname, '..', 'test-src', 'files', 'xhr-target.html')
            targetSource = FS.readFileSync(targetPath, 'utf8')
            test.equal(window.responseText, targetSource)
            test.done()
        checkReady(clientWindow, tests)

    # Using $.get, make an AJAX request using a relative URL.
    # This appears to be giving us trouble when running the jQuery test suite.
    'jQuery XHR - relative' : (test) ->
        clientWindow = initTest('browser6', 'http://localhost:3001/xhr-jquery-relative.html')
        browser = server.browsers.find('browser6')
        window = browser.window
        document = window.document
        tests = () ->
            targetPath = Path.join(__dirname, '..', 'test-src', 'files', 'xhr-target.html')
            targetSource = FS.readFileSync(targetPath, 'utf8')
            test.equal(window.responseText, targetSource)
            test.done()
        checkReady(clientWindow, tests)

    'teardown' : (test) ->
        server.once('close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        )
        server.close()
