FS   = require('fs')
Path = require('path')


exports.inject = (window, shared) ->
    vt = window.vt = {}

    vt.shared = shared

    # TODO: instead of vt.launch, we should have a launch function on the Browser.
    # We can wrap vt-node-lib's Browser object here, and expose the API we want to
    # the client.
    # This requires wrapping BrowserManager.createBrowser.
    # Maybe we just attach our own so it's vt.createBrowser, which calls
    # BrowserManager.createBrowser to create the actual Browser, then wraps it in
    # an object that exposes an API.
    vt.launch = (browser) ->
        window.open("/browsers/#{browser.id}/index.html")

    vt.switchTo = (browser) ->
        # TODO: requires an API on client side.
    
    vt.embed = (browser) ->
        # TODO

    vt.currentBrowser = () ->
        # TODO

    # Have to do the require here to avoid circular dependency.
    vt.BrowserManager = global.browsers

    vt.Model = require('./api/model')
