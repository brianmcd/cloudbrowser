URL             = require('url')
LocationBuilder = require('../../src/server/location').LocationBuilder

lastEvent = null

MockBrowser =
    # TODO: Test that entrypoint changes appropriately.
    app :
        entryPoint : '/'
    window :
        location : {}
        document :
            createEvent : () ->
                return {initEvent : () ->}
        dispatchEvent : () ->
            lastEvent = 'hashchange'
    load : () ->
        lastEvent = 'pagechange'
    setLocation : (url) ->
        @window.location = URL.parse(url)
        self = this
        for prop in ['protocol', 'host', 'hostname',
                     'port', 'pathname', 'search', 'hash']
             @window.location[prop] = @window.location[prop] || ''

Location = LocationBuilder(MockBrowser)

exports['basic'] = (test) ->
    loc = new Location('http://www.google.com/awesome/page.html')
    test.equal(loc.protocol, 'http:')
    test.equal(loc.host, 'www.google.com')
    test.equal(loc.hostname, 'www.google.com')
    test.equal(loc.port, '')
    test.equal(loc.pathname, '/awesome/page.html')
    test.equal(loc.search, '')
    test.equal(loc.hash, '')
    test.done()

exports['test navigation'] = (test) ->
    lastEvent = null
    MockBrowser.setLocation('http://www.google.com')
    loc = new Location('http://www.google.com/newpage.html')
    test.equal(lastEvent, 'pagechange')
    lastEvent = null
    
    MockBrowser.setLocation('http://www.site.com')
    loc = new Location('http://www.site.com')
    test.equal(lastEvent, null)

    MockBrowser.setLocation('http://www.google.com')
    loc = new Location('http://www.google.com/#!update')
    test.equal(lastEvent, 'hashchange')
    lastEvent = null
    
    MockBrowser.setLocation('http://www.google.com')
    loc = new Location('http://www.google.com')
    test.equal(lastEvent, null)

    loc.href = 'http://www.google.com/page2.html'
    test.equal(lastEvent, 'pagechange')
    test.done()

exports['test hashchange'] = (test) ->
    lastEvent = null
    # None of these tests should cause navigation, only hash changes.
    MockBrowser.setLocation('http://www.google.com')
    loc = new Location('http://www.google.com')
    test.equal(lastEvent, null)

    loc.href = 'http://www.google.com/#!/more/stuff'
    test.equal(lastEvent, 'hashchange')
    lastEvent = null

    MockBrowser.setLocation('http://www.google.com/#!/more/stuff')
    loc.href = 'http://www.google.com/#!/more/stuff'
    test.equal(lastEvent, null)

    loc.href = 'http://www.google.com/#!changedagain'
    test.equal(lastEvent, 'hashchange')
    test.done()

# TODO: test navigating by setting properties like pathname
