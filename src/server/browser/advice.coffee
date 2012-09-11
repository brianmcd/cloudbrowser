ClientEvents      = require('../../shared/event_lists').clientEvents
{isVisibleOnClient} = require('../../shared/utils')

adviseMethod = (obj, name, func) ->
    originalMethod = obj.prototype[name]
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
exports.addAdvice = (dom) ->
    dom.cloudBrowserAugmentation = true
    {html, events} = dom

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

    # Advice for: Node.insertBefore
    #
    # var insertedNode = parentNode.insertBefore(newNode, referenceNode);
    adviseMethod html.Node, 'insertBefore', (parent, args, rv) ->
        elem = args[0]
        browser = getBrowser(parent)
        browser.emit 'DOMNodeInserted',
            target : elem
            relatedNode : parent
        # Note: unlike the DOM, we only emit DOMNodeInsertedIntoDocument
        # on the root of a removed subtree, meaning the handler should check
        # to see if it has children.
        if isVisibleOnClient(parent, browser)
            browser.emit 'DOMNodeInsertedIntoDocument',
                target : elem
                relatedNode : parent

    # Advice for: Node.removeChild
    #
    # var oldChild = node.removeChild(child);
    adviseMethod html.Node, 'removeChild', (parent, args, rv) ->
        # Note: Unlike DOM, we only emit DOMNodeRemovedFromDocument on the root
        # of the removed subtree.
        browser = getBrowser(parent)
        if isVisibleOnClient(parent, browser)
            elem = args[0]
            browser.emit 'DOMNodeRemovedFromDocument',
                target : elem
                relatedNode : parent
    
    # Advice for AttrNodeMap.[set|remove]NamedItem
    #
    # This catches changes to node attributes.
    # type : either 'ADDITION' or 'REMOVAL'
    do () ->
        attributeHandler = (type) ->
            return (map, args, rv) ->
                attr = if type == 'ADDITION'
                    args[0]
                else
                    rv
                if !attr then return

                target = map._parentNode
                browser = getBrowser(target)
                if isVisibleOnClient(target, browser)
                    browser.emit 'DOMAttrModified',
                        target : target
                        attrName : attr.name
                        newValue : attr.value
                        attrChange : type
                    ###
                    if /input|textarea|select/.test(target.tagName?.toLowerCase())
                        process.nextTick () ->
                            doc = target._ownerDocument
                            ev = doc.createEvent('HTMLEvents')
                            ev.initEvent('change', false, false)
                            target.dispatchEvent(ev)
                    ###
        # setNamedItem(node)
        adviseMethod html.AttrNodeMap,
                          'setNamedItem',
                          attributeHandler('ADDITION')
        # attr = removeNamedItem(string)
        adviseMethod html.AttrNodeMap,
                     'removeNamedItem',
                     attributeHandler('REMOVAL')

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

    # Advice for: CharacterData._nodeValue
    #
    # This is the only way to detect changes to the text contained in a node.
    adviseProperty html.CharacterData, '_nodeValue',
        setter : (elem, value) ->
            if elem._parentNode?
                browser = getBrowser(elem)
                if isVisibleOnClient(elem._parentNode, browser)
                    browser.emit 'DOMCharacterDataModified',
                        target : elem
                        value  : value

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
                name = "on#{type}"
                # TODO: remove listener if this is set to something not a function
                for eventTarget in [html.HTMLElement, html.HTMLDocument]
                    eventTarget.prototype.__defineSetter__ name, (func) ->
                        rv = this["__#{name}"] = func
                        getBrowser(this).emit 'AddEventListener',
                            target      : this
                            type        : type
                        return rv
                    eventTarget.prototype.__defineGetter__ name, () ->
                        return this["__#{name}"]

    createFrameAttrHandler = (namespace) ->
        return (elem, args, rv) ->
            # If this isn't attached to the document, the DOMNodeInsertedIntoDocument
            # listener we register in BrowserServer#DOMNodeInserted will emit
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

    # This list is from:
    #   http://dev.w3.org/csswg/cssom/#the-cssstyledeclaration-interface
    cssAttrs = [
        'azimuth', 'background', 'backgroundAttachment', 'backgroundColor',
        'backgroundImage', 'backgroundPosition', 'backgroundRepeat', 'border',
        'borderCollapse', 'borderColor', 'borderSpacing', 'borderStyle',
        'borderTop', 'borderRight', 'borderBottom', 'borderLeft',
        'borderTopColor', 'borderRightColor', 'borderBottomColor',
        'borderLeftColor', 'borderTopStyle', 'borderRightStyle',
        'borderBottomStyle', 'borderLeftStyle', 'borderTopWidth',
        'borderRightWidth', 'borderBottomWidth', 'borderLeftWidth',
        'borderWidth', 'bottom', 'captionSide', 'clear', 'clip', 'color',
        'content', 'counterIncrement', 'counterReset', 'cue', 'cueAfter',
        'cueBefore', 'cursor', 'direction', 'display', 'elevation',
        'emptyCells', 'cssFloat', 'font', 'fontFamily', 'fontSize',
        'fontSizeAdjust', 'fontStretch', 'fontStyle', 'fontVariant',
        'fontWeight', 'height', 'left', 'letterSpacing', 'lineHeight',
        'listStyle', 'listStyleImage', 'listStylePosition', 'listStyleType',
        'margin', 'marginTop', 'marginRight', 'marginBottom', 'marginLeft',
        'markerOffset', 'marks', 'maxHeight', 'maxWidth', 'minHeight',
        'minWidth', 'orphans', 'outline', 'outlineColor', 'outlineStyle',
        'outlineWidth', 'overflow', 'padding', 'paddingTop', 'paddingRight',
        'paddingBottom', 'paddingLeft', 'page', 'pageBreakAfter',
        'pageBreakBefore', 'pageBreakInside', 'pause', 'pauseAfter',
        'pauseBefore', 'pitch', 'pitchRange', 'playDuring', 'position',
        'quotes', 'richness', 'right', 'size', 'speak', 'speakHeader',
        'speakNumeral', 'speakPunctuation', 'speechRate', 'stress',
        'tableLayout', 'textAlign', 'textDecoration', 'textIndent',
        'textShadow', 'textTransform', 'top', 'unicodeBidi', 'verticalAlign',
        'visibility', 'voiceFamily', 'volume', 'whiteSpace', 'widows', 'width',
        'wordSpacing', 'zIndex'
    ]

    # Advice for: Element.style.*
    # For each possible style property, add a setter to emit advice.
    do () ->
        proto = html.CSSStyleDeclaration.prototype
        cssAttrs.forEach (attr) ->
            proto.__defineSetter__ attr, (val) ->
                # cssom seems to use some CSSStyleDeclaration objects
                # internally, so we only want to emit instructions if there
                # is a parent element pointer, meaning this CSSStyleDeclaration
                # belongs to an element.
                parent = this._parentElement
                prop = "_#{attr}"

                # To explain this if statement, see cssom's
                #    CSSStyleDeclaration.js.
                # CSSStyleDeclaration treats itself like an array, with each
                # index containing a string for a property that has been set
                # on the object.  See CSSStyleDeclaration#setProperty.
                # The array indices are used by the cssText getter to iterate
                # over the CSS properties that have been set, so not doing this
                # was causing cssText to miss properties, and therefore our
                # serializer to miss CSS attributes (due to JSDOM's StyleAttr
                # object, which uses cssText internally).
                if !this[prop]
                    this[this.length++] = attr
                rv = this[prop] = val
                if parent
                    browser = getBrowser(parent)
                    if isVisibleOnClient(parent, browser)
                        browser.emit 'DOMStyleChanged',
                            target    : parent
                            attribute : attr
                            value     : val
                return rv
            proto.__defineGetter__ attr, () ->
                return @["_#{attr}"]
