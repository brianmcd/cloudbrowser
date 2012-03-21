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
        @addToBrowserList(shim)
        return shim

    close : () ->
        for browser in @browsers
            delete @browsers[browser.id]
            @removeFromBrowserList(browser)
            browser.close()


module.exports = MultiProcessBrowserManager
