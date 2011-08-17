Path      = require('path')
TestCase  = require('nodeunit').testCase
Server    = require('../lib/server')
Bootstrap = require('../lib/client/dnode_client')

reqCache = require.cache
for entry of reqCache
    if /jsdom/.test(entry)
        delete reqCache[entry]

JSDOM     = require('jsdom')

server = null

initTest = (browserID, url) ->
    browsers = server.browsers
    browsers.create(browserID, url)
    document = JSDOM.jsdom()
    window = document.parentWindow
    window.__envSessionID = browserID
    Bootstrap(window, document)
    return window

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

    'teardown' : (test) ->
        server.once('close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        )
        server.close()
