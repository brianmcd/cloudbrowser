# Abstract base class for browser management strategies.
class BrowserManager
    find : () ->
        throw new Error("BrowserManager subclass must implement find.")

    create : () ->
        throw new Error("BrowserManager subclass must implement create.")

    close : () ->
        throw new Error("BrowserManager subclass must implement close.")

module.exports = BrowserManager
