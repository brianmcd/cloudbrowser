# TODO: JSDOM is missing defaultValue and defaultChecked setters for HTMLInputElement
# TODO: JSDOM is missing defaultValue for HTMLTextAreaElement

advise = (obj, name, func) ->
    originalMethod = obj.prototype[name]
    obj.prototype[name] = () ->
        rv = originalMethod.apply(this, arguments)
        func(this, arguments, rv)
        return rv

# TODO: rename params, cause core is the jscore core, DOMs is DOM.  that is dumb.
exports.addAdvice = (core, DOM) ->
    # Wrap the HTMLDocument constructor so we can emit an event when one is
    # created.  We need this so we can tag Document nodes.
    oldDoc = core.HTMLDocument
    core.HTMLDocument = () ->
        oldDoc.apply(this, arguments)
        DOM.emit 'DocumentCreated',
            target : this

    core.HTMLDocument.prototype = oldDoc.prototype

    # insertBefore looks like:
    # var insertedElement = parentElement.insertBefore(newElement, referenceElement);
    advise core.Node, 'insertBefore', (parent, args, rv) ->
        elem = args[0]
        DOM.emit 'DOMNodeInserted',
            target : elem
            relatedNode : parent
        # Note: unlike the DOM, we only emit DOMNodeInsertedIntoDocument
        # on the root of a removed subtree, meaning the handler should check
        # to see if it has children.
        if parent._attachedToDocument
            DOM.emit 'DOMNodeInsertedIntoDocument',
                target : elem
                relatedNode : parent

    # removeChild looks like:
    # var oldChild = element.removeChild(child);
    advise core.Node, 'removeChild', (parent, args, rv) ->
        elem = args[0]
        # Note: Unlike DOM, we only emit DOMNodeRemovedFromDocument on the root
        # of the removed subtree.
        if parent._attachedToDocument
            DOM.emit 'DOMNodeRemovedFromDocument',
                target : elem
                relatedNode : parent
    
    # TODO: make sure this catches attribute changes.
    # type : either 'ADDITION' or 'REMOVAL'
    attributeHandler = (type) ->
        return (map, args, rv) ->
            attr = if type == 'ADDITION'
                args[0]
            else
                rv
            if !attr then return

            target = map._parentNode
            if target._attachedToDocument
                DOM.emit 'DOMAttrModified',
                    target : target
                    attrName : attr.name
                    newValue : attr.value
                    attrChange : type

    # setNamedItem(node)
    advise core.AttrNodeMap, 'setNamedItem', attributeHandler('ADDITION')
    # attr = removeNamedItem(string)
    advise core.AttrNodeMap, 'removeNamedItem', attributeHandler('REMOVAL')

    do () ->
        obj = core.CharacterData.prototype
        oldSetter = obj.__lookupSetter__('_nodeValue')
        obj.__defineSetter__ '_nodeValue', (value) ->
            rv = oldSetter.apply(this, arguments)
            DOM.emit 'DOMCharacterDataModified',
                target : this
            return rv


# TODO TODO: need to update this.
exports.wrapStyle = (core, DOM) ->
    # JSDOM level2/style.js uses the style getter to lazily create the 
    # CSSStyleDeclaration object for the element.  To be able to emit
    # the right instruction in the style object advice, we need to have
    # a pointer to the element that owns the style object, so we create it
    # here.
    do () ->
        proto = core.HTMLElement.prototype
        getter = proto.__lookupGetter__('style')
        proto.__defineGetter__ 'style', () ->
            style = getter.call(this)
            style._parentElement = this
            return style

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

    # For each possible style property, add a DOM to emit advice.
    do () ->
        proto = core.CSSStyleDeclaration.prototype
        cssAttrs.forEach (attr) ->
            proto.__defineSetter__ attr, (val) ->
                # cssom seems to use some CSSStyleDeclaration objects
                # internally, so we only want to emit instructions if there
                # is a parent element pointer, meaning this CSSStyleDeclaration
                # belongs to an element.
                if this._parentElement
                    DOM.emit 'DOMPropertyUpdate',
                        targetID : this._parentElement.__nodeID
                        style : true
                        prop : attr
                        value : val
                return @["_#{attr}"] = val
            proto.__defineGetter__ attr, () ->
                return @["_#{attr}"]
