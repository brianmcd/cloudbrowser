Location = require('../../lib/dom/location')

exports['tests'] =
    'basic test' : (test) ->
        loc = new Location('http://www.google.com/awesome/page.html',
                           'http://www.google.com/awesome/page.html', () ->)
        test.equal(loc.protocol, 'http:')
        test.equal(loc.host, 'www.google.com')
        test.equal(loc.hostname, 'www.google.com')
        test.equal(loc.port, '')
        test.equal(loc.pathname, '/awesome/page.html')
        test.equal(loc.search, '')
        test.equal(loc.hash, '')
        test.done()

    'test navigation' : (test) ->
        called = false
        loc = new Location('http://www.google.com/newpage.html',
                           'http://www.google.com', () -> called = true)
        test.ok(called)
        
        loc = new Location('http://www.site.com', 'http://www.site.com', () ->
            test.ok(false)
        )
        loc = new Location('http://www.google.com/#!update',
                           'http://www.google.com/', () -> test.ok(false)
        )
        loc = new Location('http://www.google.com',
                           'http://www.google.com', () -> test.done()
        )
        loc.href = 'http://www.google.com/page2.html'

    'test hashchange' : (test) ->
        called = false
        loc = new Location('http://www.google.com', 'http://www.google.com', () ->
            # None of these tests should cause navigation, only hash changes.
            test.ok(false)
        )
        loc.on('hashchange', () ->
            called = true
        )
        loc.href = 'http://www.google.com/#!more/stuff'
        test.ok(called)
        called = false
        loc.href = 'http://www.google.com/#!changedagain'
        test.ok(called)
        loc.href = 'http://www.google.com/#!changedagain'
        test.equal(called, false)
        test.done()

