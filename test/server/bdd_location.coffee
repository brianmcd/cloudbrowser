Browser        = require('../../src/server/browser')
Path           = require('path')
Async          = require('async')
Server         = require('../../src/server')
MongoInterface = require('../../src/server/mongo_interface')

# Using 'should' style BDD assertions
# It adds the 'should' method to Object.prototype
chai      = require('chai')
sinon     = require('sinon')
sinonChai = require('sinon-chai')
should    = chai.should()
chai.use(sinonChai)

getProjectRoot = () ->
    projectRoot = process.argv[1].split('/')
    projectRoot.pop() for i in [0..3]
    projectRoot = projectRoot.join("/")
    return projectRoot

browser = null

initialize = (done) ->
    dbName = "test_cloudbrowser"
    config =
        port        : 4000
        test_env    : true
        compression : false
        homePage    : false
        defaultUser : {email : "test", ns : "local"}
    mongoInterface = null
    path = Path.resolve(__dirname, '../files/index.html')
    Async.waterfall [
        (next) ->
            mongoInterface = new MongoInterface(dbName, next)
        (next) ->
            server  = new Server(config, [], getProjectRoot(), mongoInterface)
            browser = new Browser(1, {}, server)
            server.applications.createAppFromFile(path, next)
        (app, next) ->
            browser.load(app)
            next(null)
    ], done

describe "location", () ->
    before (done) ->
        initialize(done)

    beforeEach () ->
        browser.window.location = "http://www.example.com"

    it "should parse the url string and assign all the properties correctly",
    () ->

        browser.window.location = "http://www.google.com:80/one/page.htm?q=hello#!hash"

        loc = browser.window.location
        loc.protocol.should.equal('http:')
        loc.host.should.equal('www.google.com:80')
        loc.hostname.should.equal('www.google.com')
        loc.port.should.equal('80')
        loc.pathname.should.equal('/one/page.htm')
        loc.search.should.equal('?q=hello')
        loc.hash.should.equal('#!hash')

    it "should load the application at the url into the browser when assigned" +
    " with a new host", () ->
        mockBrowser = sinon.mock(browser)
        mockBrowser.expects("load").once().withExactArgs("http://www.google.com/")

        browser.window.location = "http://www.google.com"

        mockBrowser.verify()

    it "should load the application at the url into the browser when assigned" +
    " with a new page", () ->
        mockBrowser = sinon.mock(browser)
        mockBrowser.expects("load").once().withExactArgs("http://www.example.com/newpage")

        browser.window.location = "http://www.example.com/newpage"

        mockBrowser.verify()

    # Acc to http://nodejs.org/api/url.html#url_url_format_urlobj
    # and the code of browser/location.coffee,
    # when the host field is not empty, changes in port and hostname 
    # will not cause a page load.
    # In normal browsers, it does cause a page load.
    it "should load the application at the url into the browser when one" +
    " of its properties is assigned to", () ->
        mockBrowser = sinon.mock(browser)
        mockBrowser.expects("load").once()
            .withExactArgs("file://www.example.com/")
        mockBrowser.expects("load").once()
            .withExactArgs("file://www.google.com:3078/")

        browser.window.location['protocol'] = "file:"
        browser.window.location['host'] = "www.google.com:3078"

        mockBrowser.verify()

    it "should cause a hash change when assigned a new hash mark on the" +
    " same page", (done) ->

        mockBrowser = sinon.mock(browser)
        mockBrowser.expects("load").never()

        dispatchEventStub = sinon.stub browser.window, "dispatchEvent", (event) ->
            try
                event._type.should.equal('hashchange')
                event.newURL.should.equal("http://www.example.com/#!hash1")
                mockBrowser.verify()
                done()
            catch e
                done(e)
            finally
                browser.window.dispatchEvent.restore()

        browser.window.location = "http://www.example.com/#!hash1"

        mockBrowser.verify()

    describe "hashchange testing", () ->
        beforeEach (done) ->
            dispatchEventStub = sinon.stub browser.window, "dispatchEvent", (event) ->
                browser.window.dispatchEvent.restore()
                done()
            browser.window.location = "http://www.example.com/#!hash1"

        it "should cause a hash change when assigned a different hash mark on" +
        " the same page", (done) ->

            mockBrowser = sinon.mock(browser)
            mockBrowser.expects("load").never()
            counter = 0

            dispatchEventStub = sinon.stub browser.window, "dispatchEvent", (event) ->
                try
                    event._type.should.equal('hashchange')
                    event.newURL.should.equal("http://www.example.com/#!hash4")
                    browser.window.dispatchEvent.restore()
                    done()
                catch e
                    done(e)

            browser.window.location = "http://www.example.com/#!hash4"

            mockBrowser.verify()

        it "should cause a hash change when the hash mark is removed"
        , (done) ->

            mockBrowser = sinon.mock(browser)
            mockBrowser.expects("load").never()
            counter = 0

            dispatchEventStub = sinon.stub browser.window, "dispatchEvent", (event) ->
                try
                    event._type.should.equal('hashchange')
                    event.newURL.should.equal("http://www.example.com/")
                    browser.window.dispatchEvent.restore()
                    done()
                catch e
                    done(e)

            browser.window.location = "http://www.example.com/"

            mockBrowser.verify()

    it "should not cause any change when assigned the same url", () ->
        mockBrowser = sinon.mock(browser)
        mockBrowser.expects("load").never()

        browser.window.location = "http://www.example.com"

        mockBrowser.verify()

    it "should not cause a page load when assigned an empty string to any of its" +
    " properties", () ->
        mockBrowser = sinon.mock(browser)
        mockBrowser.expects("load").never()

        oldLocation = browser.window.location

        browser.window.location['protocol'] = ""

        browser.window.location.should.equal(oldLocation)

        mockBrowser.verify()

    describe "assign", () ->
        it "should navigate to the given url", () ->
            mockBrowser = sinon.mock(browser)
            mockWindow  = sinon.mock(browser.window)
            mockBrowser.expects("load").once()
                .withExactArgs("http://www.example.com/newpage")

            browser.window.location.assign("http://www.example.com/newpage")

            mockBrowser.verify()
            mockWindow.verify()

    describe.skip "replace", () ->
        it "should remove the current page from session history and navigate" +
            " to the given page"

    describe.skip "reload", () ->
        it "should reload the current page"
