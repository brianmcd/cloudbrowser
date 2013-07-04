Browser        = require('../../src/server/browser')
{EventEmitter} = require('events')
{createBrowserServer} = require('../helpers')
Path           = require('path')

{fireEvent, createBrowserServer} = require('../helpers')

exports['load app'] = (test) ->
    b = createBrowserServer(Path.resolve(__dirname,'../files/basic.html')).browser
    b.once 'PageLoaded', () ->
        test.notEqual(b.window, null)
        test.notEqual(b.window.cloudbrowser, null)
        test.notEqual(b.window.document, null)
        test.done()

# This doesn't test remote browser anymore
###
exports['test remote browsing'] = (test) ->
    b = createBrowserServer(Path.resolve(__dirname,'../files/basic.html')).browser
    b.once 'PageLoaded', () ->
        test.notEqual(b.window, null)
        doc = b.window.document
        test.notEqual(doc, null)
        test.notEqual(doc.body, null)
        div = doc.getElementsByTagName('div')[0]
        test.notEqual(div, null)
        test.equal(div.textContent, 'Testing')
        test.done()
###

exports['test addEventListener advice'] = (test) ->
    {browser} = createBrowserServer(Path.resolve(__dirname,'../files/basic.html'))
    events = ['blur', 'click', 'change', 'mousedown', 'mousemove']
    count = 0
    browser.on 'AddEventListener', (params) ->
        return if params.type is 'load' or params.type is 'hashchange'
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
    {browser} = createBrowserServer(Path.resolve(__dirname,'../files/event_processor.html'))
    events = ['mouseover', 'click', 'dblclick', 'change', 'focus']
    count = 0
    browser.on 'AddEventListener', (params) ->
        {type} = params
        return if type is 'load' or type is 'DOMNodeInsertedIntoDocument' or type is 'hashchange'
        test.equal(events[count++], params.type)
        if count == events.length
            test.done()

exports['test event inference - attribute handlers'] = (test) ->
    {browser} = createBrowserServer(Path.resolve(__dirname,'../files/event_processor_attributes.html'))
    events = ['focus', 'click', 'change', 'mouseover']
    count = 0
    browser.on 'AddEventListener', (params) ->
        {type} = params
        return if type is 'load' or type is 'DOMNodeInsertedIntoDocument' or type is 'hashchange'
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
