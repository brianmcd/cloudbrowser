Async = require('async')
NwGlobal = require('nwglobal')

class BrowserManager
    constructor : (@scope, @format) ->
        @browsers = []

    find : (id) ->
        return browser for browser in @browsers when browser.id is id

    add : (browserConfig, scope) ->
        browser = @find(browserConfig.getID())
        if browser then return browser
        browser = new Browser(browserConfig, @scope, @format)
        @browsers.push(browser)

        return browser

    remove : (id) ->
        browser = @find(id)
        idx = @browsers.indexOf(browser)
        return @browsers.splice(idx, 1)

# Exporting
this.BrowserManager = BrowserManager
