EventProcessor = require('../../lib/browser/event_processor')
Browser        = require('../../lib/browser/browser')
Server         = require('../../lib/server')
Path           = require('path')

server = null

exports['tests'] =
    'setup' : (test) ->
        filepath = Path.join(__dirname, '..', '..', 'test-src', 'files')
        server = new Server(filepath)
        server.once 'ready', () ->
            test.done()

    'basic test' : (test) ->
        browser = new Browser('browser')
        processor = browser.events
        test.notEqual(processor, null)
        test.done()

    'test addEventListener advice' : (test) ->
        browser = new Browser('browser', 'http://localhost:3001/basic.html')
        processor = browser.events
        events = ['blur', 'click', 'change', 'mousedown', 'mousemove']
        count = 0
        processor.on 'addEventListener', (params) ->
            test.equal(events[count++], params.type)
            if count == events.length
                test.done()
        browser.window.addEventListener 'load', () ->
            div = browser.window.document.getElementById('div1')
            div.addEventListener('load', () ->)
            div.addEventListener('blur', () ->)
            div.addEventListener('junk', () ->)
            div.addEventListener('click', () ->)
            div.addEventListener('change', () ->)
            div.addEventListener('mousedown', () ->)
            div.addEventListener('mousemove', () ->)

    'test event inference' : (test) ->
        browser = new Browser('browser',
                              'http://localhost:3001/event_processor.html')
        processor = browser.events
        events = ['mouseover', 'click', 'dblclick', 'change', 'focus']
        count = 0
        processor.on 'addEventListener', (params) ->
            test.equal(events[count++], params.type)
            if count == events.length
                test.done()
        
    'teardown' : (test) ->
        server.once 'close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        server.close()
