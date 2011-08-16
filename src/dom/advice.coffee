# BIG TODO: real style wrapping
# TODO: form handling
# TODO: JSDOM is missing defaultValue and defaultChecked setters for HTMLInputElement
# TODO: JSDOM is missing defaultValue for HTMLTextAreaElement
# TODO: entity reference, notationnode?
# TODO: How should we handle cookie?
# TODO: JSDOM is missing 'body' setter for HTMLDocument
# TODO: createElement needs to tag document nodes when creating frames/iframes.

isDOMNode = (node) -> (node?.ELEMENT_NODE == 1)

# dom - the jsdom dom implementation
# wrapper - must have emit and nodes
exports.addAdvice = (dom, wrapper) ->
    # TODO: change event names to DOMMethod and DOMProperty

    # func gets passed the original return value and the 'this' value.
    # If func returns true, then we will echo this property update.
    # Otherwise, we just return the rv.
    wrapProperty = (obj, prop, func) ->
        originalSetter = obj.__lookupSetter__(prop)
        if !originalSetter?
            throw new Error "Missing a setter for #{prop}"
        obj.__defineSetter__(prop, (value) ->
            #console.log("#{prop} called")
            rv = originalSetter.call(this, value)
            if !func? || func(this, arguments, rv)
                if value.__nodeID?
                    value = wrapper.nodes.get(value.__nodeID)
                params =
                    targetID : this.__nodeID
                    prop : prop
                    value : value
                wrapper.emit('DOMPropertyUpdate', params)
            return rv
        )

    wrapMethod = (obj, name, func) ->
        originalMethod = obj[name]
        obj[name] = ->
            #console.log("#{name} called #{arguments[0]}")
            rv = originalMethod.apply(this, arguments)
            # Don't allow any operations on scripts to get to client.
            if (rv?.tagName?.toLowerCase() == 'script') ||
               (this?.tagName?.toLowerCase() == 'script')
                return rv
            if isDOMNode(rv) && (rv.__nodeID == undefined)
                wrapper.nodes.add(rv)
            if !func? || func(this, arguments, rv)
                rvID = if rv? then rv.__nodeID else null
                params =
                    targetID : this.__nodeID
                    rvID : rvID
                    method : name
                    args : wrapper.nodes.scrub(arguments)
                wrapper.emit('DOMUpdate', params)
            return rv

    # w3c Level 2 Core
    # NOTE: we don't wrap appendChild because JSDOM implements it using
    # insertBefore, so wrapping it would cause duplicate instructions.
    # We don't wrap cloneNode because it calls already wrapped DOM
    # methods behind the scenes
    for method in ['insertBefore', 'replaceChild', 'removeChild']
        wrapMethod(dom.Node.prototype, method)
    wrapProperty(dom.Node.prototype, 'nodeValue')

    # Note: have to use this methods variable for multi-line arrays in a for/in
    # loop or else coffee-script complains.
    methods = ['setAttribute', 'setAttributeNS',
               'removeAttribute', 'removeAttributeNS']
    for method in methods
        do (method) ->
            wrapMethod(dom.Element.prototype, method, (elem, args, rv) ->
                tagName = elem.tagName.toLowerCase()
                attr = if /NS$/.test(method)
                    args[1].toLowerCase()
                else
                    args[0].toLowerCase()
                if tagName == 'iframe' || tagName == 'frame'
                    if attr == 'src'
                        return false
                return true
            )

    methods = ['setAttributeNode', 'setAttributeNodeNS',
               'removeAttributeNode', 'removeAttributeNodeNS']
    for method in methods
        do (method) ->
            wrapMethod(dom.Element.prototype, method, (elem, args, rv) ->
                tagName = elem.tagName.toLowerCase()
                attr = args[0] # Attribute node
                if tagName == 'iframe' || tagName == 'frame'
                    if attr.name.toLowerCase() == 'src'
                        return false
                return true
            )

    methods = ['createTextNode', 'createAttribute', 'createDocumentFragment',
               'createComment', 'createCDATASection', 'importNode',
               'createAttributeNS']
    for method in methods
        wrapMethod(dom.Document.prototype, method)

    for method in ['createElement', 'createElementNS']
        do (method) ->
            wrapMethod(dom.Document.prototype, method, (elem, args, rv) ->
                tagName =
                    if /NS$/.test(method)
                        args[1].toLowerCase()
                    else
                        args[0].toLowerCase()
                if tagName == 'iframe' || tagName == 'frame'
                    undefined # TODO tag document and emit client instruction
                return true
            )

    for method in ['appendData', 'insertData', 'deleteData', 'replaceData']
        wrapMethod(dom.CharacterData.prototype, method)
    wrapProperty(dom.CharacterData.prototype, 'data')
    wrapProperty(dom.Attr.prototype, 'value')
    wrapMethod(dom.Text.prototype, 'splitText')
    wrapProperty(dom.Text.prototype, 'value')

    # w3c Level 2 HTML
    # Note: most of the properties on HTML elements are implemented with
    # setters that call setAttribute behind the scenes, so we don't have
    # to wrap them.
    for property in ['title', 'cookie']
        wrapProperty(dom.HTMLDocument.prototype, property)
    wrapProperty(dom.HTMLTitleElement.prototype, 'text')
    wrapProperty(dom.HTMLMetaElement.prototype, 'httpEquiv')
    wrapProperty(dom.HTMLIsIndexElement.prototype, 'prompt')
    for method in ['submit', 'reset']
        wrapMethod(dom.HTMLFormElement.prototype, method)
    for method in  ['add', 'remove', 'blur', 'focus']
        wrapMethod(dom.HTMLSelectElement.prototype, method)
    for property in ['selectedIndex', 'value']
        wrapProperty(dom.HTMLSelectElement.prototype, property)
    for property in ['selected']
        wrapProperty(dom.HTMLOptionElement.prototype, property)

    for method in ['blur', 'focus', 'select']
        wrapMethod(dom.HTMLTextAreaElement.prototype, method)
    for method in ['blur', 'focus']
        wrapMethod(dom.HTMLAnchorElement.prototype, method)
    methods = ['createTHead', 'deleteTHead', 'createTFoot', 'deleteTFoot',
               'createCaption', 'deleteCaption', 'insertRow', 'deleteRow']
    for method in methods
        wrapMethod(dom.HTMLTableElement.prototype, method)
    for method in ['insertRow', 'deleteRow']
        wrapMethod(dom.HTMLTableSectionElement.prototype, method)
    for method in ['insertCell', 'deleteCell']
        wrapMethod(dom.HTMLTableRowElement.prototype, method)
    wrapProperty(dom.HTMLTableCellElement.prototype, 'headers')
