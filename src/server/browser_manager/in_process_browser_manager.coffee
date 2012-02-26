BrowserServer  = require('../browser_server')
BrowserManager = require('./browser_manager')

class InProcessBrowserManager extends BrowserManager
    constructor : (@mountPoint, @defaultApp) ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    create : (appOrUrl = @defaultApp, id = @generateUUID()) ->
        bserver = @browsers[id] = new BrowserServer(id, @mountPoint)
        bserver.load(appOrUrl)
        return bserver

    # Close all browsers
    close : () ->
        for browser in @browsers
            browser.close()

module.exports = InProcessBrowserManager
