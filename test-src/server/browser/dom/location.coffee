URL             = require('url')
TestCase        = require('nodeunit').testCase
LocationBuilder = require('../../../../lib/server/browser/dom/location').LocationBuilder

lastEvent = null
MockWindow =
    setLocation : (url) ->
        @location = URL.parse(url)
        @location.protocol = '' if !@location.protocol
        @location.host     = '' if !@location.host
        @location.hostname = '' if !@location.hostname
        @location.port     = '' if !@location.port
        @location.pathname = '' if !@location.pathname
        @location.search   = '' if !@location.search
        @location.hash     = '' if !@location.hash
    document :
        createEvent : () -> {initEvent : () ->}
    dispatchEvent : () ->
        lastEvent = 'hashchange'

MockBrowser =
    load : () ->
        lastEvent = 'pagechange'

MockDOM =
    loadPage : () ->

Location = LocationBuilder(MockWindow, MockBrowser, MockDOM)

exports['tests'] = TestCase
    setUp : (callback) ->
        lastEvent = null
        callback()

    tearDown : (callback) ->
        lastEvent = null
        callback()

    'basic test' : (test) ->
        loc = new Location('http://www.google.com/awesome/page.html')
        test.equal(loc.protocol, 'http:')
        test.equal(loc.host, 'www.google.com')
        test.equal(loc.hostname, 'www.google.com')
        test.equal(loc.port, '')
        test.equal(loc.pathname, '/awesome/page.html')
        test.equal(loc.search, '')
        test.equal(loc.hash, '')
        test.done()

    'test navigation' : (test) ->
        MockWindow.setLocation('http://www.google.com')
        loc = new Location('http://www.google.com/newpage.html')
        test.equal(lastEvent, 'pagechange')
        lastEvent = null
        
        MockWindow.setLocation('http://www.site.com')
        loc = new Location('http://www.site.com')
        test.equal(lastEvent, null)

        MockWindow.setLocation('http://www.google.com')
        loc = new Location('http://www.google.com/#!update')
        test.equal(lastEvent, 'hashchange')
        lastEvent = null
        
        MockWindow.setLocation('http://www.google.com')
        loc = new Location('http://www.google.com')
        test.equal(lastEvent, null)

        loc.href = 'http://www.google.com/page2.html'
        test.equal(lastEvent, 'pagechange')
        test.done()

    'test hashchange' : (test) ->
        # None of these tests should cause navigation, only hash changes.
        MockWindow.setLocation('http://www.google.com')
        loc = new Location('http://www.google.com')
        test.equal(lastEvent, null)

        loc.href = 'http://www.google.com/#!/more/stuff'
        test.equal(lastEvent, 'hashchange')
        lastEvent = null

        MockWindow.setLocation('http://www.google.com/#!/more/stuff')
        loc.href = 'http://www.google.com/#!/more/stuff'
        test.equal(lastEvent, null)

        loc.href = 'http://www.google.com/#!changedagain'
        test.equal(lastEvent, 'hashchange')
        test.done()

    # TODO: test navigating by setting properties like pathname
