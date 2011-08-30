EventEmitter = require('events').EventEmitter
bootstrap    = require('../client/dnode_client')

class TestClient extends EventEmitter
    constructor : (id, dom) ->
        @id = id
        # Make sure we get a fresh JSDOM, not one that has been augmented with
        # advice.
        @jsdom = dom.getFreshJSDOM()
        @document = @jsdom.jsdom()
        @window = @document.parentWindow
        # Attach this testClient to the window, so that the client code can
        # emit events on the testClient (like 'testDone')
        @window.testClient = this
        @window.__envSessionID = id
        bootstrap(@window, @document)

module.exports = TestClient
