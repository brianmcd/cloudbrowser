Config = require('../../src/shared/config')
{serialize} = require('../../src/server/serializer')
{getFreshJSDOM} = require('../helpers')
Config.resourceProxy = false

jsdom = getFreshJSDOM()

compareRecords = (actual, expected) ->
    test.notEqual(actual, null)
    test.equal(actual.length, 5)

    for i in [0..4]
        test.equal(actual[i].type,   expected[i].type)
        test.equal(actual[i].id,     expected[i].id)
        test.equal(actual[i].parent, expected[i].parent)
        test.equal(actual[i].name,   expected[i].name)
        actualAttrs = actual[i].attributes
        if !actualAttrs
            test.equal(actualAttrs, expected[i].attributes)
            continue
        expectedAttrs = expected[i].attributes
        test.notEqual(expectedAttrs, null)
        for own key, val of actualAttrs
            test.equal(expectedAttrs[key], val)

exports['test null'] = (test) ->
    doc = jsdom.jsdom()
    records = serialize(null, null, doc)
    test.notEqual(records, null)
    test.ok(records instanceof Array)
    test.equal(records.length, 0)
    test.done()

exports['basic test'] = (test) ->
    doc = jsdom.jsdom("<html>" +
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

    records = serialize(doc, null, doc)
    test.done()
