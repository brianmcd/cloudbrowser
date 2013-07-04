{EventEmitter}  = require('events')
{serialize}     = require('../../src/server/browser_server/serializer')
{getFreshJSDOM} = require('../helpers')

config = global.server.config

jsdom = getFreshJSDOM()

createDoc = (html) ->
    return jsdom.jsdom(html, null, {browser : new EventEmitter})
    

compareRecords = (actual, expected, test) ->
    test.equal(actual.length, expected.length)
    test.notEqual(actual, null)

    for i in [0..actual.length - 1]
        test.equal(actual[i].type, expected[i].type)
        test.equal(actual[i].name, expected[i].name)
        actualAttrs = actual[i].attributes
        if !actualAttrs
            test.equal(actualAttrs, expected[i].attributes)
            continue
        expectedAttrs = expected[i].attributes
        test.notEqual(expectedAttrs, null)
        for own key, val of actualAttrs
            test.equal(expectedAttrs[key], val)

exports['test null'] = (test) ->
    doc = createDoc()
    records = serialize(null, null, doc, config)
    test.notEqual(records, null)
    test.ok(records instanceof Array)
    test.equal(records.length, 0)
    test.done()

exports['elements'] = (test) ->
    doc = createDoc("<html>" +
                      "<head></head>" +
                      "<body><div><input type='text'></input></div></body>" +
                      "</html>")
    expected = [
        type   : 'element'
        name   : 'html'
        attributes : undefined
    ,
        type : 'element'
        name : 'head'
        attributes : undefined
    ,
        type : 'element'
        name : 'body'
        attributes : undefined
    ,
        type : 'element'
        name : 'div'
        attributes : undefined
    ,
        type : 'element'
        name : 'input'
        attributes :
            type : 'text'
    ]

    actual = serialize(doc, null, doc, config)
    compareRecords(actual, expected, test)
    test.done()

exports['comments'] = (test) ->
    doc = createDoc("<html><body><!--Here's my comment!--></body></html>")
    expected = [
        type : 'element'
        name : 'html'
        attributes : undefined
    ,
        type : 'element'
        name : 'body'
        attributes : undefined
    ,
        type : 'comment'
        name : undefined
        value : "Here's my comment!"
        attributes : undefined
    ]
    actual = serialize(doc, null, doc, config)
    compareRecords(actual, expected, test)
    test.done()

exports['text'] = (test) ->
    doc = createDoc("<html><body>Here's my text!</body></html>")
    expected = [
        type : 'element'
        name : 'html'
        attribites : undefined
    ,
        type : 'element'
        name : 'body'
        attributes : undefined
    ,
        type : 'text'
        name : undefined
        attributes : undefined
        value : "Here's my text!"
    ]
    actual = serialize(doc, null, doc, config)
    compareRecords(actual, expected, test)
    test.done()
