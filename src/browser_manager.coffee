Browser = require('./browser/browser')
Hat     = require('hat')

# It is anticipated that this class will expand to have a persistant store and
# high performance implementation.
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
        b = @browsers[id] = new Browser(id, shared)
        if url?
            b.load(url)
        else
            b.loadApp(app)
        return b

    # Close all browsers
    close : () ->
        for browser in @browsers
            browser.close()

module.exports = BrowserManager
