Path    = require('path')
Server  = require('../lib/server')
Browser = require('../lib/server/browser')

server = null
browsers = null

exports['tests'] =
    'setup' : (test) ->
        server = new Server
            appPath : '/'
            staticDir : Path.join(__dirname, '..', 'test-src', 'files')
        server.once 'ready', () ->
            browsers = server.browsers
            test.done()

    'basic' : (test) ->
        count = 0
        events = [
            {type : 'DOMNodeInsertedIntoDocument'}
            {type : 'DOMAttrModified'}
            {type : 'DOMNodeRemovedFromDocument'}
            {type : 'DOMNodeRemovedFromDocument'}
        ]
        handleEvent = (type, event) ->
            test.equal(type, events[count].type)
            if ++count == events.length
                test.done()
        browser = new Browser('browser1')
        browser.load('http://localhost:3001/blank.html')
        browser.once 'load', () ->
            ['DOMNodeInsertedIntoDocument',
             'DOMNodeRemovedFromDocument',
             'DOMAttrModified'].forEach (type) ->
                 browser.on type, (event) ->
                     handleEvent(type, event)
            doc = browser.window.document
            div = doc.createElement('div')
            div2 = doc.createElement('div')
            div.appendChild(div2)
            doc.body.appendChild(div)
            div.align = 'center'
            div.removeChild(div2)
            doc.body.removeChild(div)

    'teardown' : (test) ->
        server.once 'close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        server.close()
