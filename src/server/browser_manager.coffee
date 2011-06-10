Browser = require('./browser')

# It is anticipated that this class will expand to have a persistant store and
# high performance implementation.
# TODO: Need an efficient way to store pid->browser and browserid->browser mappings.
#       Could use getters/setters so that when it's set, we add it to that index.
class BrowserManager
    constructor : () ->
        @browsers = {}

    find : (id, callback) ->
        if typeof id != 'string'
            id = id.toString()
        if callback and typeof callback == 'function'
            callback(@browsers[id])

    create : (id, url) ->
        if typeof id != 'string'
            id = id.toString()
        if @browsers[id]?
            throw new Error "Tried to create an already existing BrowserInstance"
        @browsers[id] = new Browser(id, url)

module.exports = BrowserManager
