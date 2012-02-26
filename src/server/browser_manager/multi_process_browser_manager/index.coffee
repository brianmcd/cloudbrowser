BrowserManager    = require('../browser_manager')
BrowserServerShim = require('./browser_server_shim')

class MultiProcessBrowserManager extends BrowserManager
    constructor : (@mountPoint, @defaultApp) ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    create : (appOrUrl = @defaultApp, id = @generateUUID()) ->
        shim = @browsers[id] = new BrowserServerShim(id, @mountPoint)
        shim.load(appOrUrl)
        return shim

    close : () ->
        for browser in @browsers
            browser.close()

module.exports = MultiProcessBrowserManager
