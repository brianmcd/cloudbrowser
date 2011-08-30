Browser = require('./browser/browser')

# It is anticipated that this class will expand to have a persistant store and
# high performance implementation.
class BrowserManager
    constructor : () ->
        @browsers = {}

    find : (id) ->
        if typeof id != 'string'
            id = id.toString()
        return @browsers[id]

    create : (id, url) ->
        if typeof id != 'string'
            id = id.toString()
        if @browsers[id]?
            throw new Error "Tried to create an already existing BrowserInstance"
        return @browsers[id] = new Browser(id, url)

module.exports = BrowserManager
