Path          = require('path')
FS            = require('fs')
ResourceProxy = require('../../src/server/browser_server/resource_proxy')

#TODO: test CSS re-writing
#TODO: test re-writing of resources in iframes (re: base url)
#TODO: re-enable last test with global server.

describe "ResourceProxy", () ->
    proxy = null

    beforeEach () ->
        proxy = new ResourceProxy('http://www.google.com')

    describe "addURL", () ->
        it "should add absolute urls", () ->
            idx = proxy.addURL('http://www.vt.edu')
            idx.should.equal(0)
            proxy.urlsByIndex[idx].should.equal('http://www.vt.edu')
            idx = proxy.addURL('http://news.ycombinator.com')
            idx.should.equal(1)
            proxy.urlsByIndex[idx].should.equal('http://news.ycombinator.com')

        it "should resolve relative urls based on the base url", () ->
            idx = proxy.addURL('/index.html')
            proxy.urlsByIndex[idx].should.equal('http://www.google.com/index.html')

            proxy2 = new ResourceProxy('http://www.google.com/test/index.html')
            idx = proxy2.addURL('new.html')
            proxy2.urlsByIndex[idx].should
                .equal('http://www.google.com/test/new.html')

            idx = proxy2.addURL('/new.html')
            idx.should.equal(1)
            proxy2.urlsByIndex[idx].should
                .equal('http://www.google.com/new.html')

            idx = proxy2.addURL('../index.html')
            idx.should.equal(2)
            proxy2.urlsByIndex[idx].should
                .equal('http://www.google.com/index.html')

###
    describe "fetch", () ->
        it "should", () ->
            filesPath = Path.join(__dirname, '../files')
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
