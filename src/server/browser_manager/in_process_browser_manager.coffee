BrowserServer  = require('../browser_server')
BrowserManager = require('./browser_manager')

class InProcessBrowserManager extends BrowserManager
    constructor : (@server, @mountPoint, @defaultApp) ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    create : (appOrUrl = @defaultApp, isAuthenticationVB, id = @generateUUID()) ->
        browser = @browsers[id] = new BrowserServer(@server, id, @mountPoint, isAuthenticationVB)
        browser.load(appOrUrl)
        @addToBrowserList(browser)
        browser.once 'BrowserClose', () =>
            @close(browser)
        return browser

    # Close all browsers
    closeAll : () ->
        for browser in @browsers
            delete @browsers[browser.id]
            browser.close()
            @removeFromBrowserList(browser)
    
    close : (browser) ->
        if !browser?
            throw new Error("Must pass a browser to close")
        console.log("InProcessBrowserManager closing: #{browser.id}")
        @removeFromBrowserList(browser)
        delete @browsers[browser.id]
        browser.close()

module.exports = InProcessBrowserManager
