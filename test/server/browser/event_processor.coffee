EventProcessor = require('../../../lib/server/browser/event_processor')
Browser        = require('../../../lib/server/browser')
Server         = require('../../../lib/server')
Path           = require('path')

server = null

exports['tests'] =
    'setup' : (test) ->
        filepath = Path.join(__dirname, '..', '..', '..', 'test-src', 'files')
        server = new Server
            appPath : '/'
            staticDir : filepath
        server.once 'ready', () ->
            test.done()

    'basic test' : (test) ->
        browser = new Browser('browser')
        processor = browser.events
        test.notEqual(processor, null)
        test.done()

    'test addEventListener advice' : (test) ->
        browser = new Browser('browser')
        browser.load('http://localhost:3001/basic.html')
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

    'test event inference - addEventListener' : (test) ->
        browser = new Browser('browser')
        browser.load('http://localhost:3001/event_processor.html')
        processor = browser.events
        events = ['mouseover', 'click', 'dblclick', 'change', 'focus']
        count = 0
        processor.on 'addEventListener', (params) ->
            test.equal(events[count++], params.type)
            if count == events.length
                test.done()

    'test event inference - attribute handlers' : (test) ->
        browser = new Browser('browser')
        browser.load('http://localhost:3001/event_processor_attributes.html')
        processor = browser.events
        events = ['click', 'change', 'mouseover', 'focus']
        count = 0
        processor.on 'addEventListener', (params) ->
            # Make sure that we intercept attribute handlers correctly.
            test.equal(events[count++], params.type)
            if count == events.length
                window = browser.window
                document = window.document
                # Now we test to make sure the event handler actually work.
                ev = document.createEvent('MouseEvents')
                ev.initMouseEvent('click', false, true)
                window.div.dispatchEvent(ev)
                ev = document.createEvent('HTMLEvents')
                ev.initEvent('change', false, true)
                window.input.dispatchEvent(ev)
                ev = document.createEvent('MouseEvents')
                ev.initMouseEvent('mouseover', false, true)
                window.p.dispatchEvent(ev)
                ev = document.createEvent('HTMLEvents')
                ev.initEvent('focus', false, true)
                window.div.dispatchEvent(ev)
                # Each event handler should have incremented count once.
                test.equal(window.count, 4)
                test.done()
        
    'teardown' : (test) ->
        server.once 'close', () ->
            reqCache = require.cache
            for entry of reqCache
                if /jsdom/.test(entry)
                    delete reqCache[entry]
            test.done()
        server.close()
