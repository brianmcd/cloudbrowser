Browser        = require('../../src/server/browser')
{EventEmitter} = require('events')

{fireEvent, createRemoteBrowserServer} = require('../helpers')

defaultAppBrowsers = global.defaultApp.browsers

exports['basic test'] = (test) ->
    b = defaultAppBrowsers.create().browser
    b.on 'PageLoaded', () ->
        test.done()

exports['load app'] = (test) ->
    b = defaultAppBrowsers.create().browser
    b.once 'PageLoaded', () ->
        test.notEqual(b.window, null)
        test.notEqual(b.window.vt, null)
        test.notEqual(b.window.document, null)
        test.done()

exports['test remote browsing'] = (test) ->
    b = createRemoteBrowserServer('http://localhost:3001/test/files/basic.html').browser
    b.once 'PageLoaded', () ->
        test.notEqual(b.window, null)
        doc = b.window.document
        test.notEqual(doc, null)
        test.notEqual(doc.body, null)
        div = doc.getElementsByTagName('div')[0]
        test.notEqual(div, null)
        test.equal(div.textContent, 'Testing')
        test.done()

exports['test addEventListener advice'] = (test) ->
    {browser} = createRemoteBrowserServer('http://localhost:3001/test/files/basic.html')
    events = ['blur', 'click', 'change', 'mousedown', 'mousemove']
    count = 0
    browser.on 'AddEventListener', (params) ->
        return if params.type == 'load'
        test.equal(events[count++], params.type)
        if count == events.length
            test.done()
    browser.once 'PageLoaded', () ->
        div = browser.window.document.getElementById('div1')
        div.addEventListener('blur', () ->)
        div.addEventListener('click', () ->)
        div.addEventListener('change', () ->)
        div.addEventListener('mousedown', () ->)
        div.addEventListener('mousemove', () ->)

exports['test event inference - addEventListener'] = (test) ->
    {browser} = createRemoteBrowserServer('http://localhost:3001/test/files/event_processor.html')
    events = ['mouseover', 'click', 'dblclick', 'change', 'focus']
    count = 0
    browser.on 'AddEventListener', (params) ->
        {type} = params
        return if type == 'load' || type == 'DOMNodeInsertedIntoDocument'
        test.equal(events[count++], params.type)
        if count == events.length
            test.done()

exports['test event inference - attribute handlers'] = (test) ->
    {browser} = createRemoteBrowserServer('http://localhost:3001/test/files/event_processor_attributes.html')
    events = ['focus', 'click', 'change', 'mouseover']
    count = 0
    browser.on 'AddEventListener', (params) ->
        {type} = params
        return if type == 'load' || type == 'DOMNodeInsertedIntoDocument'
        {window} = browser
        {document} = window
        div   = document.getElementById('div1')
        input = document.getElementById('input1')
        p     = document.getElementById('p1')
        # Make sure that we intercept attribute handlers correctly.
        test.equal(events[count++], type)
        if count == events.length
            # Now we test to make sure the event handler actually work.
            fireEvent(browser, 'click',     div)
            fireEvent(browser, 'change',    input)
            fireEvent(browser, 'mouseover', p)
            fireEvent(browser, 'focus',     div)
            # Each event handler should have incremented count once.
            test.equal(window.count, 4)
            test.done()
