Hat  = require('hat')
{ko} = require('../../api/ko')

if !global.browserList?
    global.browserList = ko.observableArray()

# Base class for browser management strategies.
# Must also define @mountPoint
class BrowserManager
    addToBrowserList : (browser) ->
        console.log("Pushing to browserList")
        global.browserList.push(browser)

    removeFromBrowserList : (browser) ->
        global.browserList.remove(browser)

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
