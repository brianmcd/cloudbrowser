Hat  = require('hat')
Weak = require('weak')
ko   = require('../../api/ko')

# TODO: rename, make this a real global browser list.
#       need to change debug page to use this.
global.weakRefList = {}

# Base class for browser management strategies.
# Must also define @mountPoint
class BrowserManager
    addToBrowserList : (browser) ->
        if process.env.WAS_FORKED
            id = browser.id
            process.send
                type: 'browserCreated'
                id: id
            global.weakRefList[id] = Weak browser, () ->
                delete global.weakRefList[id]
                process.send
                    type: 'browserCollected'
                    id: id

    removeFromBrowserList : (browser) ->

    find : () ->
        throw new Error("BrowserManager subclass must implement find.")

    create : (app, query, user, id) ->
        throw new Error("BrowserManager subclass must implement create.")

    close : (browser, user) ->
        throw new Error("BrowserManager subclass must implement close.")

    generateUUID : () ->
        id = Hat()
        while @find(id)
            id = Hat()
        return id

module.exports = BrowserManager
