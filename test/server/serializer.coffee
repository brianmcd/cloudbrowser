{EventEmitter}  = require('events')
{serialize}     = require('../../src/server/browser_server/serializer')
{getFreshJSDOM} = require('../helpers')

# TODO Write one test with compression:true in config

describe "serializer", () ->
    jsdom = null

    before () ->
        jsdom = getFreshJSDOM()

    createDoc = (html) ->
        return jsdom.jsdom(html, null, {browser : new EventEmitter})

    compareRecords = (actual, expected) ->
        actual.length.should.equal(expected.length)
        for i in [0..actual.length - 1]
            actualAttrs = actual[i].attributes
            if not actualAttrs
                # This is the only way to  check for undefined
                # with the 'should' style
                should = require('chai').should()
                should.not.exist(expected[i].attributes)
                continue
            actual[i].type.should.equal(expected[i].type)
            actual[i].name.should.equal(expected[i].name)
            expectedAttrs = expected[i].attributes
            expectedAttrs.should.not.be.null
            for own key, val of actualAttrs
                expectedAttrs[key].should.equal(val)

    it "should serialize an html fragment correctly", () ->
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

        actual = serialize(doc, null, doc, {})
        compareRecords(actual, expected)

    it "should serialize an html fragment containing a comment correctly", () ->
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
        actual = serialize(doc, null, doc, {})
        compareRecords(actual, expected)

    it "should serialize an html fragment containing text correctly", () ->
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
        actual = serialize(doc, null, doc, {})
        compareRecords(actual, expected)
