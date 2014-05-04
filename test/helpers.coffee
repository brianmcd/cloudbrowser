# Must include this file in all test suite files
Browser          = require('../src/server/browser')
Lists            = require('../src/shared/event_lists')
{noCacheRequire} = require('../src/shared/utils')
Path             = require('path')
Async            = require('async')

# Using 'should' style BDD assertions
# It adds the 'should' method to Object.prototype
chai      = require('chai')
sinonChai = require('sinon-chai')
should    = chai.should()
chai.use(sinonChai)

exports.createBrowser = (fileName) ->
    if not fileName then fileName = "index.html"
    path = Path.resolve(__dirname, 'files', fileName)
    browser = new Browser(1, {}, {})
    app =
        entryURL : () -> return path
        getMountPoint : () -> return "index"
    
    browser.load(app)
    return browser
    
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

exports.getFreshJSDOM = () ->
    return noCacheRequire('jsdom')
