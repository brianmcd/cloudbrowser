Hat = require('hat')

# Base class for browser management strategies.
# Must also define @mountPoint
class BrowserManager
    find : () ->
        throw new Error("BrowserManager subclass must implement find.")

    create : () ->
        throw new Error("BrowserManager subclass must implement create.")

    close : () ->
        throw new Error("BrowserManager subclass must implement close.")

    generateUUID : () ->
        id = Hat()
        while @find(id)
            id = Hat()
        return id

module.exports = BrowserManager
