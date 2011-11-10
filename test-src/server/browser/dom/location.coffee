Location = require('../../../../lib/server/browser/dom/location')

exports['tests'] =
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
        called = false
        loc = new Location('http://www.google.com/newpage.html',
                           new Location('http://www.google.com'))
        test.equal(loc.PAGECHANGE, 'http://www.google.com/newpage.html')
        test.equal(loc.HASHCHANGE, undefined)
        
        loc = new Location('http://www.site.com',
                           new Location('http://www.site.com'))
        test.equal(loc.PAGECHANGE, undefined)
        test.equal(loc.HASHCHANGE, undefined)

        loc = new Location('http://www.google.com/#!update',
                           new Location('http://www.google.com/'))
        test.equal(loc.PAGECHANGE, undefined)
        test.notEqual(loc.HASHCHANGE, undefined)
        test.equal(loc.HASHCHANGE.oldURL, 'http://www.google.com/')
        test.equal(loc.HASHCHANGE.newURL, 'http://www.google.com/#!update')

        loc = new Location('http://www.google.com',
                           new Location('http://www.google.com'))
        test.equal(loc.PAGECHANGE, undefined)
        test.equal(loc.HASHCHANGE, undefined)
        loc.once('pagechange', (url) ->
            test.equal(url, 'http://www.google.com/page2.html')
            test.done()
        )
        loc.href = 'http://www.google.com/page2.html'

    'test hashchange' : (test) ->
        called = false
        # None of these tests should cause navigation, only hash changes.
        loc = new Location('http://www.google.com',
                           new Location('http://www.google.com'))
        test.equal(loc.PAGECHANGE, undefined)
        test.equal(loc.HASHCHANGE, undefined)

        urls = [
            'http://www.google.com/'
            'http://www.google.com/#!/more/stuff'
            'http://www.google.com/#!changedagain' ]

        count = 0
        loc.on('hashchange', (oldURL, newURL) ->
            test.equal(oldURL, urls[count])
            count++
            test.equal(newURL, urls[count])
            if count == urls.length - 1
                test.done()
        )
        loc.href = 'http://www.google.com/#!/more/stuff'
        loc.href = 'http://www.google.com/#!/more/stuff'
        loc.href = 'http://www.google.com/#!changedagain'

    # TODO: test navigating by setting properties like pathname
