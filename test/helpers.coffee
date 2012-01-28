Browser = require('../src/server/browser')
Lists   = require('../src/shared/event_lists')

# TODO: this functionality should be in Browser
exports.createEmptyWindow = (callback) ->
    browser = new Browser('browser1', global.defaultApp)
    browser.once 'PageLoaded', () ->
        window = browser.window = browser.jsdom.createWindow(browser.jsdom.dom.level3.html)
        browser.augmentWindow(window)
        callback(window) if callback?

exports.fireEvent = (browser, type, node) ->
    {document} = browser.window
    group = Lists.eventTypeToGroup[type]
    ctor  = Lists.eventTypeToConstructor[type]
    ev = document.createEvent(group)
    if group[group.length - 1] == 's'
        group = group.substring(0, group.length - 1)
    ev[ctor](type, false, true)
    node.dispatchEvent(ev)
