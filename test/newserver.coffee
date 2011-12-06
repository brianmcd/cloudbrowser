Path          = require('path')
EventEmitter  = require('events').EventEmitter
Server        = require('../lib/server')
BrowserServer = require('../lib/server/browser_server')

class MockClient extends EventEmitter

server = null
browsers = null

exports['tests'] =
    'setup' : (test) ->
        server = new Server
            appPath : '/'
            staticDir : Path.join(__dirname, 'files')
        server.once 'ready', () ->
            browsers = server.browsers
            test.done()

    'basic' : (test) ->
        bserver = new BrowserServer('browser1')
        browser = bserver.browser
        client = new MockClient()
        client.on 'loadFromSnapshot', (cmd) ->
            console.log('loadFromSnapshot')
            console.log(cmd)
        client.on 'attachSubtree', (cmd) ->
            console.log('attachSubtree')
            console.log(cmd)
            test.done()
        browser.load('http://localhost:3001/blank.html')
        browser.once 'load', () ->
            doc = browser.window.document
            doc.body.appendChild(doc.createElement('div'))
            bserver.addSocket(client)
            setTimeout () ->
                testDiv = doc.createElement('div')
                embedded = doc.createElement('div')
                testDiv.appendChild(embedded)
                doc.body.appendChild(testDiv)
            , 0

    'teardown' : (test) ->
        server.once 'close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        server.close()
