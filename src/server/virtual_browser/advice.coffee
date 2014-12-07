debug = require('debug')

ClientEvents      = require('../../shared/event_lists').clientEvents
{isVisibleOnClient} = require('../../shared/utils')

logger=debug("cloudbrowser:domadvice")


adviseMethod = (obj, name, func) ->
    originalMethod = obj.prototype[name]
    logger("#{name} in #{obj} does not exsit") if not originalMethod?
    logger("invalidate func") if typeof func isnt 'function'
    obj.prototype[name] = () ->
        rv = originalMethod.apply(this, arguments)
        func(this, arguments, rv)
        return rv

adviseProperty = (obj, name, args) ->
    for own type, func of args
        do (type, func) ->
            if type == 'setter'
                oldSetter = obj.prototype.__lookupSetter__(name)
                obj.prototype.__defineSetter__ name, (value) ->
                    rv = oldSetter.apply(this, arguments)
                    func(this, value)
                    return rv
            else if type == 'getter'
                oldGetter = obj.prototype.__lookupGetter__(name)
                obj.prototype.__defineGetter__ name, () ->
                    rv = oldGetter.apply(this, arguments)
                    func(this, rv)
                    return rv

getBrowser = (node) ->
    if node.nodeType == 9 # Document
        browser = node.__browser__
    else if node.nodeType != undefined # Other Node
        browser = node._ownerDocument.__browser__
    else # Window
        browser = node.document.__browser__
    if !browser?
        console.log("Found browser on #{node.tagName} #{node.nodeType}")
        console.log("Couldn't get browser: #{node.tagName} #{node.nodeType}")
        console.log(node)
        throw new Error
    return browser

# Adds advice to a number of DOM methods so we can emit events when the DOM
# changes.
exports.addAdvice = () ->
    jsdom = require('jsdom')
    html = jsdom.level('3', 'html')
    events = jsdom.level('3', 'events')
    core = jsdom.level('3', 'core')

    # Advice for: HTMLDocument constructor
    #
    # Wrap the HTMLDocument constructor so we can emit an event when one is
    # created.  We need this so we can tag Document nodes.
    do () ->
        oldDoc = html.HTMLDocument
        # TODO: this needs to be monkey patched...or dig into jsdom to pass
        # browser to ctor.  Can we use object.clone to do a lightweight clone and then
        # just patch this method?
        html.HTMLDocument = (options) ->
            oldDoc.apply(this, arguments)
            this.__browser__ = options.browser
            options.browser.emit 'DocumentCreated',
                target : this
        html.HTMLDocument.prototype = oldDoc.prototype



    interceptDomEvents = ['DOMNodeRemoved','DOMAttrModified',
    'DOMNodeInserted', 'DOMCharacterDataModified']
    attrChangeCodeMap = {
        # 1 is actually MODIFICATION, as we only care about new value,
        # so we treat it as an addition
        '1' : 'ADDITION'
        '2' : 'ADDITION'
        '3' : 'REMOVAL'
    }
    inputTags = ['TEXTAREA', 'INPUT']

    eventDispatchInterceptor = (ev)->
        target = this
        {attrChange, type} = ev
        if not target? or interceptDomEvents.indexOf(type) < 0
            return
        try
            if type is 'DOMAttrModified'
                browser = getBrowser(target)
                attrChangeText = attrChangeCodeMap[attrChange]
                if not attrChangeText?
                    logger("illega attrChange value #{attrChange}")
                    return
                if isVisibleOnClient(target, browser)
                    browser.emit('DOMAttrModified',{
                        target : target
                        attrName : ev.attrName
                        newValue : ev.newValue
                        attrChange : attrChangeText
                    })
            if type is 'DOMNodeInserted'
                parent = ev.relatedNode
                browser = getBrowser(parent)
                return if not browser?
                
                evParam = {
                    target : target
                    relatedNode : parent
                }
                browser.emit 'DOMNodeInserted', evParam
                ###
                do not check visibility on child because child is
                 not on dom yet
                ###
                if not isVisibleOnClient(parent, browser)
                        return
                # parent is textarea and the child node is text type
                if inputTags.indexOf(parent.tagName) >= 0 and target.nodeType is 3
                    val = target.data
                    browser.emit('DOMAttrModified',{
                        target : parent
                        attrName : 'value'
                        newValue : val
                        attrChange : 'ADDITION'
                    })
                    return

                 browser.emit 'DOMNodeInsertedIntoDocument', evParam

            if type is 'DOMNodeRemoved'
                parent = ev.relatedNode
                browser = getBrowser(parent)
                return if not browser? or not isVisibleOnClient(parent, browser)
                if inputTags.indexOf(parent.tagName) >= 0 and target.nodeType is 3
                    browser.emit('DOMAttrModified',{
                        target : parent
                        attrName : 'value'
                        newValue : null
                        attrChange : 'ADDITION'
                    })
                    return

                if  isVisibleOnClient(target, browser)
                    browser.emit 'DOMNodeRemovedFromDocument',
                        target : target
                        relatedNode : parent
            if type is 'DOMCharacterDataModified'
                return if not target._parentNode?
                browser = getBrowser(target)
                if isVisibleOnClient(target._parentNode, browser)
                    browser.emit 'DOMCharacterDataModified',
                        target : target
                        value  : ev.newValue
        catch e
            logger(e)
            logger(e.stack)

    oldEventDispatcher = html.Node.prototype.dispatchEvent
    html.Node.prototype.dispatchEvent = (ev)->
        try
            oldEventDispatcher.apply(this, arguments)
            if null != ev
                eventDispatchInterceptor.apply(this, arguments)
        catch e
            logger("event dispath err #{e}")
            logger(e.stack)
            throw e




    # Advice for: HTMLOptionElement.selected property.
    #
    # The client needs to set this as a property, not an attribute, or the
    # selection won't actually be changed.
    adviseProperty html.HTMLOptionElement, 'selected',
        setter : (elem, value) ->
            process.nextTick () ->
                doc = elem._ownerDocument
                ev = doc.createEvent('HTMLEvents')
                ev.initEvent('change', false, false)
                elem.dispatchEvent(ev)
            browser = getBrowser(elem)
            if isVisibleOnClient(elem, browser)
                browser.emit 'DOMPropertyModified',
                    target   : elem
                    property : 'selected'
                    value    : value


    # Advice for: EventTarget.addEventListener
    #
    # This allows us to know which events need to be listened for on the
    # client.
    # TODO: wrap removeEventListener.
    adviseMethod events.EventTarget, 'addEventListener', (elem, args, rv) ->
        getBrowser(elem).emit 'AddEventListener',
            target      : elem
            type        : args[0]

    # Advice for: all possible attribute event listeners
    #
    # For each type of event that can be listened for on the client, we wrap
    # the corresponding "on" property on each node.
    # TODO: really, this should emit on all event types and shouldn't know
    #       about ClientEvents.
    do () ->
        for type of ClientEvents
            do (type) ->
                # TODO: remove listener if this is set to something not a function
                for eventTarget in [html.HTMLElement, html.HTMLDocument]
                    patchOnEventProperty(eventTarget.prototype, type)


    createFrameAttrHandler = (namespace) ->
        return (elem, args, rv) ->
            # If this isn't attached to the document, the DOMNodeInsertedIntoDocument
            # listener we register in VirtualBrowser#DOMNodeInserted will emit
            # ResetFrame.  If this is attached, then the HTMLFrameElement
            # setAttribute will have already deleted the old document and made a new
            # one, so we can emit ResetFrame here.
            return if !elem._attachedToDocument
            attr = if namespace
                args[1].toLowerCase()
            else
                args[0].toLowerCase()
            browser = getBrowser(elem)
            if attr == 'src' && isVisibleOnClient(elem, browser)
                browser.emit 'ResetFrame',
                    target : elem
    adviseMethod html.HTMLFrameElement, 'setAttribute', createFrameAttrHandler(false)
    adviseMethod html.HTMLFrameElement, 'setAttributeNS', createFrameAttrHandler(true)

    interceptChangeStyle = (elem, args, rv) ->
        parent = elem._parentElement
        return if !parent
        browser = getBrowser(parent)
        if isVisibleOnClient(parent, browser)
            browser.emit 'DOMStyleChanged',
                target:parent
                attribute:args[0]
                value:args[1]

    # TODO it is not safe to rely on a internal api
    adviseMethod html.CSSStyleDeclaration, 'setProperty', interceptChangeStyle
    adviseMethod html.CSSStyleDeclaration, '_setProperty', interceptChangeStyle

    # Advice for: HTMLElement.style
    #
    # JSDOM level2/style.js uses the style getter to lazily create the
    # CSSStyleDeclaration object for the element.  To be able to emit
    # the right instruction in the style object advice, we need to have
    # a pointer to the element that owns the style object, so we create it
    # here.
    adviseProperty html.HTMLElement, 'style',
        getter : (elem, rv) ->
            rv._parentElement = elem

    adviseProperty html.HTMLInputElement, 'value', 
        setter : (elem, val)->
            browser = getBrowser(elem)
            return if not browser?
            if val? and typeof val isnt 'string'
                val = String(val)
            # it is not part of standard to emit DOMAttrModified after set value
            browser.emit('DOMAttrModified',{
                target : elem
                attrName : 'value'
                newValue : val
                attrChange : 'ADDITION'
            })
            
            


patchOnEventProperty = (obj, type)->
    name = "on#{type}"
    Object.defineProperty(obj, name, {
        configurable:true
        get : ()->
            @["__#{name}"]
        set : (func)->
            try
                @["__#{name}"] = func
                getBrowser(@).emit('AddEventListener', {
                    target : this
                    type : type
                })
            catch e
                logger(e)
            return
    })

exports.patchOnEventProperty = patchOnEventProperty