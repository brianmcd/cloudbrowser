BrowserManager    = require('../browser_manager')
BrowserServerShim = require('./browser_server_shim')

class MultiProcessBrowserManager extends BrowserManager
    constructor : (@server, @mountPoint, @defaultApp) ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    create : (appOrUrl = @defaultApp, id = @generateUUID()) ->
        shim = @browsers[id] = new BrowserServerShim(id, @mountPoint)
        shim.load(appOrUrl)
        @addToBrowserList(shim)
        return shim

    closeAll : () ->
        for browser in @browsers
            delete @browsers[browser.id]
            @removeFromBrowserList(browser)
            browser.close()

    close : (browser) ->
        if !browser?
            throw new Error("Must pass a browser to close")
        console.log("InProcessBrowserManager closing: #{browser.id}")
        @removeFromBrowserList(browser)
        delete @browsers[browser.id]
        browser.close()

module.exports = MultiProcessBrowserManager
