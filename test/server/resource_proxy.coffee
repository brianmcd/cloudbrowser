Path          = require('path')
FS            = require('fs')
ResourceProxy = require('../../src/server/browser_server/resource_proxy')


#TODO: test CSS re-writing
#TODO: test re-writing of resources in iframes (re: base url)
#TODO: re-enable last test with global server.
exports['test basic'] = (test) ->
    proxy = new ResourceProxy('http://www.google.com')
    test.notEqual(proxy, null)
    test.equal(proxy.urlsByIndex.length, 0)
    test.equal(Object.keys(proxy.urlsByName).length, 0)
    test.done()

exports['test absolute urls'] = (test) ->
    proxy = new ResourceProxy('http://www.google.com')
    test.notEqual(proxy, null)
    idx = proxy.addURL('http://www.vt.edu')
    test.equal(idx, 0)
    test.equal(proxy.urlsByIndex[idx], 'http://www.vt.edu')
    idx = proxy.addURL('http://news.ycombinator.com')
    test.equal(idx, 1)
    test.equal(proxy.urlsByIndex[idx], 'http://news.ycombinator.com')
    test.done()

exports['test relative urls'] = (test) ->
    proxy = new ResourceProxy('http://www.google.com')
    test.notEqual(proxy, null)
    idx = proxy.addURL('/index.html')
    test.equal(idx, 0)
    test.equal(proxy.urlsByIndex[idx],
               'http://www.google.com/index.html')

    proxy2 = new ResourceProxy('http://www.google.com/test/index.html')
    test.notEqual(proxy2, null)
    idx = proxy2.addURL('new.html')
    test.equal(idx, 0)
    test.equal(proxy2.urlsByIndex[idx],
              'http://www.google.com/test/new.html')
    idx = proxy2.addURL('/new.html')
    test.equal(idx, 1)
    test.equal(proxy2.urlsByIndex[idx],
              'http://www.google.com/new.html')
    idx = proxy2.addURL('../index.html')
    test.equal(idx, 2)
    test.equal(proxy2.urlsByIndex[idx],
               'http://www.google.com/index.html')
    test.done()

###
exports['test fetch'] = (test) ->
    filesPath = Path.join(__dirname, 'files')
    server = new Server
        app : '/'
        staticDir : filesPath
    # mock response obejct
    class Response ()
        constructor : (@expected) ->
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
    targetPath = Path.join(__dirname, 'files', 'xhr-target.html')
    targetSource = FS.readFileSync(targetPath, 'utf8')
    res = new Response(targetSource)

    server.once 'ready', () ->
        proxy.fetch(idx, res)
###
