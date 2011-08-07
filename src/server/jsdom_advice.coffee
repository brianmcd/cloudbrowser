exports.addAdvice = (dom, wrapper) ->
    isDOMNode = (node) ->
        node? &&
        (typeof node.ELEMENT_NODE == 'number') &&
        (node.ELEMENT_NODE == 1)               &&
        (node.ATTRIBUTE_NODE == 2)

    nodes = wrapper.nodes
    propName = nodes.propName

    wrapProperty = (parent, prop) ->
        originalSetter = parent.__lookupSetter__(prop)
        if !originalSetter?
            throw new Error "Missing a setter for #{prop}"
        parent.__defineSetter__ prop, (value) ->
            #console.log "Setter for #{prop} called."
            rv = originalSetter.call this, value
            if !this.tagName? || (this.tagName != 'SCRIPT')
                if value[propName]?
                    value = nodes.get(value[propName])
                params =
                    targetID : this[propName]
                    prop : prop
                    value : value
                wrapper.emit 'DOMPropertyUpdate', params
            return rv

    wrapMethod = (parent, method) ->
        originalMethod = parent[method]
        parent[method] = ->
            #console.log "#{method} called"
            rv = originalMethod.apply(this, arguments)
            if isDOMNode(rv) && rv[propName] == undefined
                nodes.add(rv)
            rvID = if rv? then rv[propName] else null
            #printMethodCall(this, method, arguments, rvID)
            if !this.tagName? || (this.tagName != 'SCRIPT')
                params =
                    targetID : this[propName]
                    rvID : rvID
                    method : method
                    args : nodes.scrub(arguments)
                # TODO: Change event name to show that this is a method, not prop
                wrapper.emit 'DOMUpdate', params
            return rv

    createWrappedObjectList(dom).forEach (info) ->
        obj = info.object
        info.methods?.forEach (method) ->
            wrapMethod(obj, method)
        info.properties?.forEach (prop) ->
            wrapProperty(obj, prop)

printMethodCall = (node, method, args, rvID) ->
    args = @nodes.scrub(args)
    nodeName = node.name || node.nodeName
    argStr = ""
    for arg in args
        argStr += "#{arg}, "
    argStr = argStr.replace(/,\s$/, '')
    console.log "#{rvID} = #{nodeName}.#{method}(#{argStr})"

# TODO: don't build this at runtime.
createWrappedObjectList = (dom) ->
    list = []
    # Level 2 Core:
    list.push
        object     : dom.Node.prototype
        # NOTE: we don't wrap appendChild because JSDOM implements it using
        # insertBefore, so wrapping it would cause duplicate instructions.
        # We don't wrap cloneNode because it calls already wrapped DOM
        # methods behind the scenes
        methods    : ['insertBefore', 'replaceChild', 'removeChild']
        properties : ['nodeValue']
    list.push
        object     : dom.Element.prototype
        methods    : ['setAttribute', 'setAttributeNS', 'removeAttribute',
                      'removeAttributeNS', 'setAttributeNode',
                      'setAttributeNodeNS', 'removeAttributeNode',
                      'removeAttributeNodeNS']
    list.push
        object     : dom.Document.prototype
        methods    : ['createElement', 'createTextNode',
                      'createAttribute', 'createDocumentFragment',
                      'createComment', 'createCDATASection', 'importNode',
                      'createElementNS', 'createAttributeNS']
    list.push
        object     : dom.CharacterData.prototype
        methods    : ['appendData', 'insertData', 'deleteData', 'replaceData']
        properties : ['data']
    list.push
        object     : dom.Attr.prototype
        properties : ['value']
    list.push
        object     : dom.Text.prototype
        methods    : ['splitText']
        properties : ['value']
    # TODO: entity reference, notationnode?
    # Level 2 HTML
    list.push
        object     : dom.HTMLDocument.prototype
        properties : ['title', 'cookie']
        # TODO: JSDOM is missing 'body' setter for HTMLDocument
    list.push
        object     : dom.HTMLElement.prototype
        # TODO: will wrapping these cause things to fire twice?  Do these
        #       manipulate Attr nodes behind the scenes?
        properties : ['id', 'title', 'lang', 'dir', 'className']
    list.push
        object     : dom.HTMLHtmlElement.prototype
        properties : ['version']
    list.push
        object     : dom.HTMLLinkElement.prototype
        properties : ['disabled', 'charset', 'href', 'hreflang', 'media',
                      'rel', 'rev', 'target', 'type']
    list.push
        object     : dom.HTMLTitleElement.prototype
        properties : ['text']
    list.push
        object     : dom.HTMLMetaElement.prototype
        properties : ['content', 'httpEquiv', 'name', 'scheme']
    list.push
        object     : dom.HTMLBaseElement.prototype
        properties : ['href', 'target']
    list.push
        object     : dom.HTMLIsIndexElement.prototype
        properties : ['prompt']
    list.push
        object     : dom.HTMLStyleElement.prototype
        properties : ['disabled', 'media', 'type']
    list.push
        object     : dom.HTMLBodyElement.prototype
        properties : ['aLink', 'background', 'bgColor', 'link', 'text',
                      'vLink']
    list.push
        object     : dom.HTMLFormElement.prototype
        # TODO: This might get wacky with submit/reset
        methods    : ['submit', 'reset']
        properties : ['name', 'acceptCharset', 'action', 'enctype',
                      'method', 'target']
    list.push
        object     : dom.HTMLSelectElement.prototype
        methods    : ['add', 'remove', 'blur', 'focus']
        properties : ['selectedIndex', 'value', 'disabled', 'multiple',
                      'name', 'size', 'tabIndex']
    list.push
        object     : dom.HTMLOptGroupElement.prototype
        properties : ['disabled', 'label']
    list.push
        object     : dom.HTMLOptionElement.prototype
        properties : ['disabled', 'label', 'selected', 'value']
        #TODO: Why doesn't defaultSelected property work?
    list.push
        object     : dom.HTMLInputElement.prototype
        #methods    : ['blur', 'focus', 'select', 'click']
        properties : ['accept',
                      'accessKey', 'align', 'alt', 'checked', 'disabled',
                      'maxLength', 'name', 'readOnly', 'size', 'src',
                      'tabIndex', 'type', 'useMap', 'value']
        #TODO: JSDOM is missing defaultValue and defaultChecked setters for HTMLInputElement
    list.push
        object     : dom.HTMLTextAreaElement.prototype
        methods    : ['blur', 'focus', 'select']
        properties : ['accessKey', 'cols', 'disabled',
                      'name', 'readOnly', 'rows', 'tabIndex', 'value']
        #TODO: JSDOM is missing defaultValue for HTMLTextAreaElement
    list.push
        object     : dom.HTMLButtonElement.prototype
        properties : ['accessKey', 'disabled', 'name', 'tabIndex', 'value']
    list.push
        object     : dom.HTMLLabelElement.prototype
        properties : ['accessKey', 'htmlFor']
    list.push
        object     : dom.HTMLLegendElement.prototype
        properties : ['accessKey', 'align']
    list.push
        object     : dom.HTMLUListElement.prototype
        properties : ['compact', 'type']
    list.push
        object     : dom.HTMLOListElement.prototype
        properties : ['compact', 'start', 'type']
    list.push
        object     : dom.HTMLDListElement.prototype
        properties : ['compact']
    list.push
        object     : dom.HTMLDirectoryElement.prototype
        properties : ['compact']
    list.push
        object     : dom.HTMLMenuElement.prototype
        properties : ['compact']
    list.push
        object     : dom.HTMLLIElement.prototype
        properties : ['type', 'value']
    list.push
        object     : dom.HTMLDivElement.prototype
        properties : ['align']
    list.push
        object     : dom.HTMLParagraphElement.prototype
        properties : ['align']
    list.push
        object     : dom.HTMLHeadingElement.prototype
        properties : ['align']
    list.push
        object     : dom.HTMLQuoteElement.prototype
        properties : ['cite']
    list.push
        object     : dom.HTMLPreElement.prototype
        properties : ['width']
    list.push
        object     : dom.HTMLBRElement.prototype
        properties : ['clear']
    list.push
        object     : dom.HTMLBaseFontElement.prototype
        properties : ['color', 'face', 'size']
    list.push
        object     : dom.HTMLFontElement.prototype
        properties : ['color', 'face', 'size']
    list.push
        object     : dom.HTMLHRElement.prototype
        properties : ['align', 'noShade', 'size', 'width']
    list.push
        object     : dom.HTMLModElement.prototype
        properties : ['cite', 'dateTime']
    list.push
        object     : dom.HTMLAnchorElement.prototype
        methods    : ['blur', 'focus']
        properties : ['accessKey', 'charset', 'coords', 'href', 'hreflang',
                      'name', 'rel', 'rev', 'shape', 'tabIndex', 'target',
                      'type']
    list.push
        object     : dom.HTMLImageElement.prototype
        properties : ['name', 'align', 'alt', 'border', 'height', 'hspace',
                      'isMap', 'longDesc', 'src', 'useMap', 'vspace',
                      'width']
    list.push
        object     : dom.HTMLObjectElement.prototype
        properties : ['code', 'align', 'archive', 'border', 'codeBase',
                      'codeType', 'data', 'declare', 'height', 'hspace',
                      'name', 'standby', 'tabIndex', 'type', 'useMap',
                      'vspace', 'width']
    list.push
        object     : dom.HTMLParamElement.prototype
        properties : ['name', 'type', 'value', 'valueType']
    list.push
        object     : dom.HTMLAppletElement.prototype
        properties : ['align', 'alt', 'archive', 'code', 'codeBase',
                      'height', 'hspace', 'name', 'object', 'vspace',
                      'width']
    list.push
        object     : dom.HTMLMapElement.prototype
        properties : ['name']
    list.push
        object     : dom.HTMLAreaElement.prototype
        properties : ['accessKey', 'alt', 'coords', 'href', 'noHref',
                      'shape', 'tabIndex', 'target']
    list.push
        object     : dom.HTMLScriptElement.prototype
        properties : ['text', 'htmlFor', 'event', 'charset', 'defer',
                      'src', 'type']
    list.push
        object     : dom.HTMLTableElement.prototype
        methods    : ['createTHead', 'deleteTHead', 'createTFoot',
                      'deleteTFoot', 'createCaption', 'deleteCaption',
                      'insertRow', 'deleteRow']
        properties : ['align', 'bgColor', 'border', 'cellPadding',
                      'cellSpacing', 'frame', 'rules', 'summary', 'width']
    list.push
        object     : dom.HTMLTableCaptionElement.prototype
        properties : ['align']
    list.push
        object     : dom.HTMLTableColElement.prototype
        properties : ['align', 'chOff', 'span', 'vAlign', 'width']
    list.push
        object     : dom.HTMLTableSectionElement.prototype
        methods    : ['insertRow', 'deleteRow']
        properties : ['align', 'ch', 'chOff', 'vAlign']
    list.push
        object     : dom.HTMLTableRowElement.prototype
        methods    : ['insertCell', 'deleteCell']
        properties : ['align', 'bgColor', 'ch', 'chOff', 'vAlign']
    list.push
        object     : dom.HTMLTableCellElement.prototype
        properties : ['abbr', 'align', 'axis', 'bgColor', 'ch', 'chOff',
                      'colSpan', 'headers', 'height', 'noWrap', 'rowSpan',
                      'scope', 'vAlign', 'width']
    list.push
        object     : dom.HTMLFrameSetElement.prototype
        properties : ['cols', 'rows']
    list.push
        object     : dom.HTMLFrameElement.prototype
        properties : ['frameBorder', 'longDesc', 'marginHeight',
                      'marginWidth', 'name', 'noResize', 'scrolling']
        #NOTE: JSDOM uses setAttribute for setting 'src'.
    list.push
        object     : dom.HTMLIFrameElement.prototype
        properties : ['align', 'frameBorder', 'height', 'longDesc',
                      'marginHeight', 'marginWidth', 'name', 'scrolling',
                      'src', 'width']
    return list
