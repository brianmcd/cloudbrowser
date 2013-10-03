{EventEmitter}  = require('events')
{getFreshJSDOM} = require('../helpers')
{addAdvice}     = require('../../src/server/browser/advice')
sinon           = require('sinon')

getAdvisedDOM = () ->
    jsdom = require('jsdom')
    {level3} = jsdom.dom
    if !level3.cloudBrowserAugmentation
        addAdvice(level3)
    return [jsdom, level3.html]

getAdvisedDoc = () ->
    [jsdom, html] = getAdvisedDOM()
    browser = new EventEmitter()
    doc = jsdom.jsdom(null, null, {browser: browser})
    browser.window = {document: doc}
    # We need to set this so isVisibleOnClient works.
    return [doc, browser]

describe "addAdvice", () ->
    [doc, browser] = [null, null]

    beforeEach () ->
        [doc, browser] = getAdvisedDoc()

    it "should fire DocumentCreated on the browser when a document is created"
    , (done) ->
        [jsdom, html] = getAdvisedDOM()
        browser = new EventEmitter
        browser.once 'DocumentCreated', (event) ->
            # Document node (nodetype 9)
            event.target.nodeType.should.equal(9)
            done()
        doc = new html.HTMLDocument({browser: browser})

    it "should fire DOMNodeInserted on the browser when a node is inserted" +
    " into another node", (done) ->
        div = doc.createElement('div')
        browser.once 'DOMNodeInserted', (event) ->
            event.target.should.equal(div)
            event.relatedNode.should.equal(doc.body)
            done()
        # Inserting at the end of body
        doc.body.insertBefore(div, null)

    it.skip "should fire DOMNodeInsertedIntoDocument on the browser when a" +
    " subtree of elements is inserted into the document, for each node of" +
    " the subtree", (done) ->
        div  = doc.createElement('div')
        div2 = doc.createElement('div2')
        iter = 0

        browser.on 'DOMNodeInsertedIntoDocument', (event) ->
            switch iter++
                when 0
                    event.target.should.equal(div)
                    event.relatedNode.should.equal(doc.body)
                    event.target.firstChild.should.equal(div2)
                when 1
                    event.target.should.equal(div1)
                    event.relatedNode.should.equal(doc.body.div)
                    done()

        div.appendChild(div2)
        doc.body.appendChild(div)

    it "should fire DOMNodeRemovedFromDocument on the browser when elements" +
    " that are part of the document are removed", (done) ->
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
        browser.on 'DOMNodeRemovedFromDocument', (event) ->
            switch iter++
                when 0
                    event.target.should.equal(div2)
                    event.relatedNode.should.equal(div)
                when 1
                    event.target.should.equal(div)
                    event.relatedNode.should.equal(doc.body)
                    done()

        # Should not trigger, since div3 isn't in doc.
        div3.removeChild(div4)
        # Should trigger.
        div.removeChild(div2)
        # Should trigger.
        doc.body.removeChild(div)

    it "should fire DOMAttrModified when some attributes of a node," +
    " attached to the document, change in value", (done) ->
        div = doc.createElement('div')
        browser.once 'DOMAttrModified', () ->
            # Should not fire for a successful test
            (false).should.be.ok
        div.setAttribute('align', 'center')
        browser.removeAllListeners('DOMAttrModified')

        doc.body.appendChild(div)

        browser.once 'DOMAttrModified', (event) ->
            event.target.should.equal(div)
            event.attrName.should.equal('data-blah')
            event.newValue.should.equal('theValue')
            event.attrChange.should.equal('ADDITION')
        div.setAttribute('data-blah', 'theValue')

        browser.once 'DOMAttrModified', (event) ->
            event.target.should.equal(div)
            event.attrName.should.equal('data-blah')
            event.attrChange.should.equal('REMOVAL')
            done()
        div.removeAttribute('data-blah')

    # For difference between properties and attributes see 
    # http://stackoverflow.com/questions/6003819/properties-and-attributes-in-html
    it "should fire DOMPropertyModified on the browser when a property" +
    " of a DOM node, attached to the document, changes", (done) ->
        opt = doc.createElement('option')

        browser.once 'DOMPropertyModified', () ->
            # Should not fire for a successful test
            (false).should.be.ok

        opt.selected = false

        browser.removeAllListeners('DOMPropertyModified')

        doc.body.appendChild(opt)

        browser.once 'DOMPropertyModified', (event) ->
            event.target.should.equal(opt)
            event.property.should.equal('selected')
            event.value.should.equal(true)

        changeListener = () ->
            opt.removeEventListener('change', changeListener)
            done()

        opt.addEventListener 'change', changeListener
        opt.selected = true

    it "should fire AddEventListener on the browser when a new listener" +
    " is added, using addEventListener method,  for an event", (done) ->
        div = doc.createElement('div')
        doc.body.appendChild(div)
        events = ['click', 'change', 'keypress', 'mousedown', 'mousemove', 'blur']
        count = 0

        browser.on 'AddEventListener', (event) ->
            event.type.should.equal(events[count])
            event.target.should.equal(div)
            if ++count is events.length
                done()

        div.addEventListener('click', () ->)
        div.addEventListener('change', () ->)
        div.addEventListener('keypress', () ->)
        div.addEventListener('mousedown', () ->)
        div.addEventListener('mousemove', () ->)
        div.addEventListener('blur', () ->)

    it "should fire AddEventListener on the browser when a new listener" +
    " is added, using on<event> method, for a client event", (done) ->
        div = doc.createElement('div')
        doc.body.appendChild(div)
        events = ['click', 'focus', 'change', 'blur']
        count = 0

        browser.on 'AddEventListener', (event) ->
            event.type.should.equal(events[count])
            event.target.should.equal(div)
            if ++count is events.length then done()

        div.onclick  = (() ->)
        div.onload   = (() ->) # Not a ClientEvent
        div.onfocus  = (() ->)
        div.onchange = (() ->)
        div.onblur   = (() ->)


    it "should fire DOMStyleChanged on the browser when the style of a node" +
    " , attached to the document, changes", (done) ->
        div = doc.createElement('div')

        browser.once 'DOMStyleChanged', () ->
            # Should not fire for a successful test
            (false).should.be.ok

        div.style.display = 'block'

        browser.removeAllListeners('DOMStyleChanged')

        doc.body.appendChild(div)

        styles = [['display', 'none'], ['text-align', 'center'], ['font-family', 'Arial']]
        count = 0

        browser.on 'DOMStyleChanged', (event) ->
            style = styles[count]
            event.target.should.equal(div)
            event.attribute.should.equal(style[0])
            event.value.should.equal(style[1])
            if ++count is styles.length then done()

        div.style.display    = 'none'
        div.style.textAlign  = 'center'
        div.style.fontFamily = 'Arial'
