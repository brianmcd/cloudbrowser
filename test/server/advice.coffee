{EventEmitter}  = require('events')
{getFreshJSDOM} = require('../helpers')
{addAdvice}     = require('../../src/server/browser/advice')

getAdvisedDOM = () ->
    jsdom = getFreshJSDOM()
    ee = new EventEmitter()
    {level3} = jsdom.dom
    addAdvice(level3, ee)
    return [ee, jsdom, level3.html]

getAdvisedDoc = () ->
    [ee, jsdom, html] = getAdvisedDOM()
    doc = jsdom.jsdom()
    # We need to set this so isVisibleOnClient works.
    ee.window = {document: doc}
    return [doc, ee]

exports['basic test'] = (test) ->
    test.expect(3)
    [ee, jsdom, html] = getAdvisedDOM()
    test.notEqual(ee, null)
    test.notEqual(jsdom, null)
    test.notEqual(html, null)
    test.done()

exports['DocumentCreated'] = (test) ->
    test.expect(1)
    [ee, jsdom, html] = getAdvisedDOM()
    ee.once 'DocumentCreated', (event) ->
        test.equal(event.target.nodeType, 9)
        test.done()
    doc = new html.HTMLDocument()

exports['DOMNodeInserted'] = (test) ->
    test.expect(3)
    [doc, ee] = getAdvisedDoc()
    div = doc.createElement('div')
    test.notEqual(div, null)
    ee.once 'DOMNodeInserted', (event) ->
        test.equal(event.target, div)
        test.equal(event.relatedNode, doc.body)
        test.done()
    doc.body.appendChild(div)

exports['DOMNodeInsertedIntoDocument'] = (test) ->
    test.expect(7)
    [doc, ee] = getAdvisedDoc()
    div = doc.createElement('div')
    div2 = doc.createElement('div2')
    insertedCount = 0
    ee.on 'DOMNodeInserted', (event) ->
        switch insertedCount++
            when 0
                test.equal(event.target, div2)
                test.equal(event.relatedNode, div)
            when 1
                test.equal(event.target, div)
                test.equal(event.relatedNode, doc.body)
    ee.once 'DOMNodeInsertedIntoDocument', (event) ->
        test.equal(event.target, div)
        test.equal(event.relatedNode, doc.body)
        test.equal(event.target.firstChild, div2)
        test.done()

    div.appendChild(div2)
    doc.body.appendChild(div)

exports['DOMNodeRemovedFromDocument'] = (test) ->
    test.expect(4)
    [doc, ee] = getAdvisedDoc()

    # These will be attached to the document.
    div = doc.createElement('div')
    div2 = doc.createElement('div2')
    div.appendChild(div2)
    doc.body.appendChild(div)

    # These won't be attached to the document.
    div3 = doc.createElement('div3')
    div4 = doc.createElement('div4')
    div3.appendChild(div4)
    
    iter = 0
    ee.on 'DOMNodeRemovedFromDocument', (event) ->
        switch iter++
            when 0
                test.equal(event.target, div2)
                test.equal(event.relatedNode, div)
            when 1
                test.equal(event.target, div)
                test.equal(event.relatedNode, doc.body)
                test.done()

    # Should not trigger, since div3 isn't in doc.
    div3.removeChild(div4)
    # Should trigger.
    div.removeChild(div2)
    # Should trigger.
    doc.body.removeChild(div)

exports['DOMAttrModified'] = (test) ->
    test.expect(7)
    [doc, ee] = getAdvisedDoc()

    div = doc.createElement('div')
    ee.once 'DOMAttrModified', () ->
        test.ok('false')
    div.setAttribute('align', 'center')
    ee.removeAllListeners('DOMAttrModified')

    doc.body.appendChild(div)

    ee.once 'DOMAttrModified', (event) ->
        test.equal(event.target, div)
        test.equal(event.attrName, 'data-blah')
        test.equal(event.newValue, 'theValue')
        test.equal(event.attrChange, 'ADDITION')
    div.setAttribute('data-blah', 'theValue')

    ee.once 'DOMAttrModified', (event) ->
        test.equal(event.target, div)
        test.equal(event.attrName, 'data-blah')
        test.equal(event.attrChange, 'REMOVAL')
        test.done()
    div.removeAttribute('data-blah')

exports['HTMLOptionElement.selected'] = (test) ->
    test.expect(3)
    [doc, ee] = getAdvisedDoc()
    opt = doc.createElement('option')
    ee.once 'DOMPropertyModified', () ->
        test.ok(false)
    opt.selected = false

    ee.removeAllListeners('DOMPropertyModified')
    doc.body.appendChild(opt)
    ee.once 'DOMPropertyModified', (event) ->
        test.equal(event.target, opt)
        test.equal(event.property, 'selected')
        test.equal(event.value, true)
    changeListener = () ->
        opt.removeEventListener('change', changeListener)
        test.done()
    opt.addEventListener 'change', changeListener
    opt.selected = true

exports['AddEventListener'] = (test) ->
    test.expect(6)
    [doc, ee] = getAdvisedDoc()
    div = doc.createElement('div')

    doc.body.appendChild(div)
    events = ['click', 'change', 'keypress']
    count = 0
    ee.on 'AddEventListener', (event) ->
        test.equal(event.type, events[count])
        test.equal(event.target, div)
        if ++count == events.length
            test.done()
    div.addEventListener('click', () ->)
    div.addEventListener('change', () ->)
    div.addEventListener('keypress', () ->)

exports['Attribute Listeners'] = (test) ->
    test.expect(8)
    [doc, ee] = getAdvisedDoc()
    div = doc.createElement('div')

    doc.body.appendChild(div)
    events = ['click', 'focus', 'change', 'blur']
    count = 0
    ee.on 'AddEventListener', (event) ->
        test.equal(event.type, events[count])
        test.equal(event.target, div)
        if ++count == events.length
            test.done()
    div.onclick = (() ->)
    div.onload = (() ->) # Not a ClientEvent
    div.onfocus = (() ->)
    div.onchange = (() ->)
    div.onblur = (() ->)

exports['DOMStyleChanged'] = (test) ->
    test.expect(9)
    [doc, ee] = getAdvisedDoc()
    div = doc.createElement('div')

    ee.once 'DOMStyleChanged', () ->
        test.ok(false)
    div.style.display = 'block'
    ee.removeAllListeners('DOMStyleChanged')

    doc.body.appendChild(div)
    styles = [['display', 'none'], ['textAlign', 'center'], ['fontFamily', 'Arial']]
    count = 0
    ee.on 'DOMStyleChanged', (event) ->
        style = styles[count]
        test.equal(event.target, div)
        test.equal(event.attribute, style[0])
        test.equal(event.value, style[1])
        if ++count == styles.length
            test.done()
    div.style.display = 'none'
    div.style.textAlign = 'center'
    div.style.fontFamily = 'Arial'
