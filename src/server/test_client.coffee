{EventEmitter}   = require('events')
ClientEngine     = require('../client/client_engine')
{noCacheRequire} = require('../shared/utils')

class TestClient extends EventEmitter
    constructor : (id) ->
        @id = id
        # Make sure we get a fresh JSDOM, not one that has been augmented with
        # advice.
        @jsdom = noCacheRequire('jsdom')
        @document = @jsdom.jsdom()
        @window = @document.parentWindow
        # Attach this testClient to the window, so that the client code can
        # emit events on the testClient (like 'testDone')
        @window.testClient = this
        @window.__envSessionID = id
        @socket = new ClientEngine(@window, @document)

    disconnect : () ->
        @socket.disconnect()

module.exports = TestClient
