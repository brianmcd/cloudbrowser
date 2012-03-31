{EventEmitter}  = require('events')
Config          = require('../../src/shared/config')
{serialize}     = require('../../src/server/browser_server/serializer')
{getFreshJSDOM} = require('../helpers')

Config.resourceProxy = false

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
    records = serialize(null, null, doc)
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
        name   : 'HTML'
        attributes : undefined
    ,
        type : 'element'
        name : 'HEAD'
        attributes : undefined
    ,
        type : 'element'
        name : 'BODY'
        attributes : undefined
    ,
        type : 'element'
        name : 'DIV'
        attributes : undefined
    ,
        type : 'element'
        name : 'INPUT'
        attributes :
            type : 'text'
    ]

    actual = serialize(doc, null, doc)
    compareRecords(actual, expected, test)
    test.done()

exports['comments'] = (test) ->
    doc = createDoc("<html><body><!--Here's my comment!--></body></html>")
    expected = [
        type : 'element'
        name : 'HTML'
        attributes : undefined
    ,
        type : 'element'
        name : 'BODY'
        attributes : undefined
    ,
        type : 'comment'
        name : undefined
        value : "Here's my comment!"
        attributes : undefined
    ]
    actual = serialize(doc, null, doc)
    compareRecords(actual, expected, test)
    test.done()

exports['text'] = (test) ->
    doc = createDoc("<html><body>Here's my text!</body></html>")
    expected = [
        type : 'element'
        name : 'HTML'
        attribites : undefined
    ,
        type : 'element'
        name : 'BODY'
        attributes : undefined
    ,
        type : 'text'
        name : undefined
        attributes : undefined
        value : "Here's my text!"
    ]
    actual = serialize(doc, null, doc)
    compareRecords(actual, expected, test)
    test.done()
