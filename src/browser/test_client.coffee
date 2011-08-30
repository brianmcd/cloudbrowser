bootstrap    = require('../client/dnode_client')

class TestClient
    constructor : (id, dom) ->
        @id = id
        # Make sure we get a fresh JSDOM, not one that has been augmented with
        # advice.
        @jsdom = dom.getFreshJSDOM()
        @document = @jsdom.jsdom()
        @window = @document.parentWindow
        @window.__envSessionID = id
        bootstrap(@window, @document)

module.exports = TestClient
