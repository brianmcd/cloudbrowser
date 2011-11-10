# TODO: rename to just advice.coffee
# TODO: test each special case

TestCase             = require('nodeunit').testCase
Emitter              = require('events').EventEmitter
TaggedNodeCollection = require('../../../../lib/shared/tagged_node_collection')
addAdvice            = require('../../../../lib/server/browser/dom/advice').addAdvice

# These are set for each test case in setUp
JSDOM = null
wrapper = null

exports['tests'] = TestCase(
    setUp : (callback) ->
        JSDOM = require('jsdom')
        wrapper = new Emitter()
        wrapper.nodes = new TaggedNodeCollection()
        addAdvice(JSDOM.dom.level3.html, wrapper)
        callback()

    tearDown : (callback) ->
        wrapper.removeAllListeners('DOMUpdate')
        wrapper.removeAllListeners('DOMPropertyUpdate')
        JSDOM = null
        wrapper = null
        reqCache = require.cache
        for entry of reqCache
            if /jsdom/.test(entry) # && !(/jsdom_wrapper/.test(entry))
                delete reqCache[entry]
        callback()

    'basic method test' : (test) ->
        doc = JSDOM.jsdom("<HTML><HEAD></HEAD><BODY></BODY></HTML>")
        count = 0
        expected = ['createElement', 'insertBefore']
        wrapper.on('DOMUpdate', (params) ->
            test.equal(params.method, expected[count++])
            if count == expected.length
                test.done()
        )
        a = doc.createElement('a')
        body = doc.getElementsByTagName('body')[0]
        body.appendChild(a)

    'basic property test' : (test) ->
        doc = JSDOM.jsdom()
        wrapper.once('DOMPropertyUpdate', (params) ->
            test.equal(params.prop, 'nodeValue')
            test.done()
        )
        text = doc.createTextNode()
        text.nodeValue = '3'

    # iframe.src attribute shouldn't be reflected on the client, but others
    # should.
    'test iframe setAttribute' : (test) ->
        doc = JSDOM.jsdom()
        iframe = doc.createElement('iframe')
        count = 0
        expected = [['height', '100px'], ['name', 'testframe'], ['width', '100px']]
        wrapper.on('DOMUpdate', (params) ->
            if params.method == 'setAttribute'
                test.equal(params.args[0], expected[count][0])
                test.equal(params.args[1], expected[count][1])
                if ++count == expected.length
                    return test.done()
            else if params.method == 'setAttributeNode'
                console.log params
                test.ok(false)
        )
        iframe.src = 'http://www.google.com'
        iframe.height = '100px'
        iframe.name = 'testframe'
        iframe.setAttribute('width', '100px')

    # script tag creation and attributes should not get reflected on the client
    'test script manipulation' : (test) ->
        doc = JSDOM.jsdom("<HTML><HEAD></HEAD><BODY></BODY></HTML>")
        head = doc.getElementsByTagName('head')[0]
        wrapper.on('DOMUpdate', (params) ->
            if params.method == 'createElement'
                if params.args[0].toLowerCase() == 'script'
                    test.ok(false, 'Created script element on client')
                if params.args[0].toLowerCase() == 'a'
                    return test.done()
            if params.targetID?
                node = wrapper.nodes.get(params.targetID)
                if node.tagName?.toLowerCase() == 'script'
                    console.log(params)
                    test.ok(false, 'Manipulated script element on client')
            if params.rvID?
                node = wrapper.nodes.get(params.rvID)
                if node.tagName?.toLowerCase() == 'script'
                    console.log(params)
                    test.ok(false, 'Manipulated script element on client')
        )
        script = doc.createElement('script')
        script.src = 'http://www.google.com'
        script2 = doc.createElement('script')
        script.text = 'var x = 3;'
        script.defer = true
        a = doc.createElement('a') # to signal end of test
)
