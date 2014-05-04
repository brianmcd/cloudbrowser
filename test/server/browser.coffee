Async          = require('async')
{EventEmitter} = require('events')

{createBrowser} = require('../helpers')

describe "Browser", () ->

    it "should have a window, and a document", (done) ->
        browser = createBrowser('basic.html')
        browser.once 'PageLoaded', () ->
            browser.window.should.not.be.null
            browser.window.document.should.not.be.null
            done()
