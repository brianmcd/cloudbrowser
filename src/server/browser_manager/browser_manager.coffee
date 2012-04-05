Hat  = require('hat')
Weak = require('weak')
ko   = require('../../api/ko')

if !global.browserList?
    global.browserList = ko.observableArray()

# TODO: something better than both of these.
global.weakRefList = {}

# Base class for browser management strategies.
# Must also define @mountPoint
class BrowserManager
    addToBrowserList : (browser) ->
        console.log("Pushing to browserList")
        #global.browserList.push(browser)
        if process.env.WAS_FORKED
            id = browser.id
            process.send
                type: 'browserCreated'
                id: id
            weakRefList[id] = Weak browser, () ->
                delete weakRefList[id]
                process.send
                    type: 'browserCollected'
                    id: id

    removeFromBrowserList : (browser) ->
        #global.browserList.remove(browser)

    find : () ->
        throw new Error("BrowserManager subclass must implement find.")

    create : (app, id) ->
        throw new Error("BrowserManager subclass must implement create.")

    close : () ->
        throw new Error("BrowserManager subclass must implement close.")

    generateUUID : () ->
        id = Hat()
        while @find(id)
            id = Hat()
        return id

module.exports = BrowserManager
