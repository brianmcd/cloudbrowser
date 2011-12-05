BrowserServer = require('./browser_server')
Hat           = require('hat')

class BrowserManager
    constructor : () ->
        @browsers = {}

    find : (id) ->
        return @browsers[id]

    create : (opts) ->
        {id, url, app, shared} = opts
        console.log("url: #{url}")
        console.log("app: #{app}")
        if !id
            id = Hat()
            # Since we allow use supplied ids, there's a very very small chance
            # that a user supplied the same id that we got back from Hat().
            while browsers[id]
                id = Hat()
        if @browsers[id]?
            throw new Error "Tried to create an already existing BrowserInstance"
        bserver = @browsers[id] = new BrowserServer
            id : id
            shared: shared
        browser = bserver.browser
        # TODO: should load/loadApp be exposed on BrowserServer?
        if url?
            browser.load(url)
        else
            browser.loadApp(app)
        return bserver

    # Close all browsers
    close : () ->
        for browser in @browsers
            browser.close()

module.exports = BrowserManager
