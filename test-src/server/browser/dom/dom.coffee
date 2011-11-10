TestCase             = require('nodeunit').testCase
DOM                  = require('../../../../lib/server/browser/dom')
TaggedNodeCollection = require('../../../../lib/shared/tagged_node_collection')

#TODO: test window.location for navigation
# Test that it emits the event at least

browser = null
exports['tests'] = TestCase(
    setUp : (callback) ->
        browser =
            dom :
                nodes : new TaggedNodeCollection()
        callback()

    tearDown : (callback) ->
        browser = null
        callback()

    'basic test' : (test) ->
        wrapper = new DOM()
        test.done()

    'test createWindow()' : (test) ->
        wrapper = new DOM(browser)
        window = wrapper.createWindow()
        test.notEqual(window.JSON, null)
        test.notEqual(window.Image, null)
        test.notEqual(window.XMLHttpRequest, null)
        test.notEqual(window.console, null)
        test.done()

    'test multiple wrappers' : (test) ->
        wrapper1 = new DOM(browser)
        wrapper2 = new DOM(browser)
        window1 = wrapper1.createWindow()
        window2 = wrapper2.createWindow()
        test.notStrictEqual(window1, window2)
        test.done()
)
