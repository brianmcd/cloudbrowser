BrowserServer  = require('../browser_server')
BrowserManager = require('./browser_manager')
Hat            = require('hat')

class InProcessBrowserManager extends BrowserManager
    constructor : () ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    create : (app, id) ->
        if !app
            throw new Error("Must pass an Application to BrowserManager#create")
        if !id
            id = Hat()
            while @browsers[id]
                id = Hat()
        bserver = @browsers[id] = new BrowserServer
            id : id,
            app : app
        browser = bserver.browser
        return bserver

    # Close all browsers
    close : () ->
        for browser in @browsers
            browser.close()

module.exports = InProcessBrowserManager
