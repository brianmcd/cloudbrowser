Browser = require('../src/server/browser')

# TODO: this functionality should be in Browser
exports.createEmptyWindow = (callback) ->
    browser = new Browser('browser1', global.defaultApp)
    browser.once 'PageLoaded', () ->
        window = browser.window = browser.jsdom.createWindow(browser.jsdom.dom.level3.html)
        browser.augmentWindow(window)
        callback(window) if callback?
