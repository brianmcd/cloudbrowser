Path          = require('path')
FS            = require('fs')
Server        = require('../../../lib/server')
ResourceProxy = require('../../../lib/server/browser/resource_proxy')

exports['tests'] =
    'basic test' : (test) ->
        proxy = new ResourceProxy('http://www.google.com')
        test.notEqual(proxy, null)
        test.equal(proxy.urlsByIndex.length, 0)
        test.equal(Object.keys(proxy.urlsByName).length, 0)
        test.done()

    'test absolute urls' : (test) ->
        proxy = new ResourceProxy('http://www.google.com')
        test.notEqual(proxy, null)
        idx = proxy.addURL('http://www.vt.edu')
        test.equal(idx, 0)
        test.equal(proxy.urlsByIndex[idx].href, 'http://www.vt.edu/')
        idx = proxy.addURL('http://news.ycombinator.com')
        test.equal(idx, 1)
        test.equal(proxy.urlsByIndex[idx].href, 'http://news.ycombinator.com/')
        test.done()

    'test relative urls' : (test) ->
        proxy = new ResourceProxy('http://www.google.com')
        test.notEqual(proxy, null)
        idx = proxy.addURL('/index.html')
        test.equal(idx, 0)
        test.equal(proxy.urlsByIndex[idx].href,
                   'http://www.google.com/index.html')

        proxy2 = new ResourceProxy('http://www.google.com/test/index.html')
        test.notEqual(proxy2, null)
        idx = proxy2.addURL('new.html')
        test.equal(idx, 0)
        test.equal(proxy2.urlsByIndex[idx].href,
                  'http://www.google.com/test/new.html')
        idx = proxy2.addURL('/new.html')
        test.equal(idx, 1)
        test.equal(proxy2.urlsByIndex[idx].href,
                  'http://www.google.com/new.html')
        idx = proxy2.addURL('../index.html')
        test.equal(idx, 2)
        test.equal(proxy2.urlsByIndex[idx].href,
                   'http://www.google.com/index.html')
        test.done()

    'test fetch' : (test) ->
        filesPath = Path.join(__dirname, '..', '..', '..', 'test-src', 'files')
        server = new Server
            appPath : '/'
            staticDir : filesPath
        # mock response obejct
        class Response
            constructor : (expected) ->
                @expected = expected
                @current = ""

            write : (data) ->
                @current += data
            
            writeHead : () ->

            end : () ->
                test.equal(@current, @expected)
                server.once 'close', () ->
                    test.done()
                server.close()

        proxy = new ResourceProxy('http://localhost:3001')
        test.notEqual(proxy, null)
        idx = proxy.addURL('/xhr-target.html')
        test.equal(idx, 0)
        test.equal(proxy.urlsByIndex[idx].href,
                   'http://localhost:3001/xhr-target.html')
        targetPath = Path.join(__dirname, '..', '..', '..', 'test-src', 'files',
                              'xhr-target.html')
        targetSource = FS.readFileSync(targetPath, 'utf8')
        res = new Response(targetSource)

        server.once 'ready', () ->
            proxy.fetch(idx, res)


