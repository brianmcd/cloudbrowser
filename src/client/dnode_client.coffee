DNode = require('dnode')
TaggedNodeCollection = require('./tagged_node_collection')

test_env = false
if process?.env?.TESTS_RUNNING
    test_env = true

module.exports = (window, document) ->
    nodes = new TaggedNodeCollection()
    if test_env
        window.__nodes = nodes

    dnodeConnection = DNode( (remote, conn) ->
        console.log "Connecting to server..."
        conn.on('ready', () ->
            console.log "Connection is ready"
            remote.auth(window.__envSessionID)
        )
        
        # Snapshot is an array of node records.  See dom/serializers.coffee.
        # This function is used to bootstrap the client so they're ready for
        # updates.
        @loadFromSnapshot = (snapshot) ->
            console.log("Loading from snapshot...")
            for record in snapshot
                node = null
                doc = null
                parent = null
                switch record.type
                    when 'document'
                        doc = document
                        if record.parent
                            doc = nodes.get(record.parent).contentDocument
                        while doc.hasChildNodes()
                            doc.removeChild(doc.firstChild)
                        delete doc.__nodeID
                        # If we just cleared the main document, start a new
                        # TaggedNodeCollection
                        if doc == document
                            nodes = new TaggedNodeCollection()
                        nodes.add(doc, record.id)
                    when 'comment'
                        doc = document
                        if record.ownerDocument
                            doc = nodes.get(record.ownerDocument)
                        node = doc.createComment(record.value)
                        nodes.add(node, record.id)
                        parent = nodes.get(record.parent)
                        parent.appendChild(node)
                    when 'element'
                        doc = document
                        if record.ownerDocument
                            doc = nodes.get(record.ownerDocument)
                        node = doc.createElement(record.name)
                        for name, value of record.attributes
                            node.setAttribute(name, value)
                        nodes.add(node, record.id)
                        parent = nodes.get(record.parent)
                        parent.appendChild(node)
                    when 'text'
                        doc = document
                        if record.ownerDocument
                            doc = nodes.get(record.ownerDocument)
                        node = doc.createTextNode(record.value)
                        nodes.add(node, record.id)
                        parent = nodes.get(record.parent)
                        parent.appendChild(node)

        @tagDocument = (params) ->
            parent = nodes.get(params.parent)
            if parent.contentDocument?.readyState == 'complete'
                nodes.add(parent.contentDocument, params.id)
            else
                listener = () ->
                    parent.removeEventListener('load', listener)
                    nodes.add(parent.contentDocument, params.id)
                parent.addEventListener('load', listener)

        # If params given, clear the document of the specified frame.
        # Otherwise, clear the global window's document.
        @clear = (params) ->
            doc = document
            frame = null
            if params?
                frame = nodes.get(params.frame)
                doc = frame.contentDocument
            while doc.hasChildNodes()
                doc.removeChild(doc.firstChild)
            # Only reset the TaggedNodeCollection if we cleared the global
            # window's document.
            if doc == document
                nodes = new TaggedNodeCollection()
            if test_env
                window.__nodes = nodes
            delete doc.__nodeID

        # Params:
        #   'method'
        #   'rvID'
        #   'targetID'
        #   'args'
        @DOMUpdate = (params) ->
            target = nodes.get(params.targetID)
            method = params.method
            rvID = params.rvID
            args = nodes.unscrub(params.args)

            if target[method] == undefined
                throw new Error("Tried to process an invalid method: #{method}")

            rv = target[method].apply(target, args)

            if rvID?
                if !rv?
                    throw new Error('expected return value')
                else if rv.__nodeID?
                    if rv.__nodeID != rvID
                        throw new Error("id issue")
                else
                    nodes.add(rv, rvID)

            #printMethodCall(target, method, args, rvID)

        @DOMPropertyUpdate = (params) ->
            target = nodes.get(params.targetID)
            prop = params.prop
            value = params.value
            if /^node\d+$/.test(value)
                value = nodes.unscrub(value)
            return target[prop] = value

        # startEvents 
        do ->
            ###
            MouseEvents = ['click', 'mousedown', 'mouseup', 'mouseover',
                           'mouseout', 'mousemove']
            ###
            MouseEvents = ['click']
            # Note: change is not a standard DOM event, but is supported by all
            # the browsers.
            #UIEvents = ['change', 'DOMFocusIn', 'DOMFocusOut', 'DOMActivate']
            UIEvents = ['change']
            HTMLEvents = [] #'submit', 'select', 'change', 'reset', 'focus', 'blur',
            #              'resize', 'scroll']
            [MouseEvents, HTMLEvents, UIEvents].forEach (group) ->
                group.forEach (eventType) ->
                    document.addEventListener eventType, (event) ->
                        if eventType == 'click'
                            console.log "#{event.type} #{event.target.__nodeID}"
                        event.stopPropagation()
                        event.preventDefault()
                        ev = {}
                        if eventType == 'change'
                            # The change event doesn't normally say have the new
                            # data attached, so we snag it.
                            ev.data = event.target.value
                        ev.target = event.target.__nodeID
                        ev.type = event.type
                        ev.bubbles = event.bubbles
                        ev.cancelable = event.cancelable # TODO: if this is no...what's that mean happened on client?
                        ev.view = null # TODO look into this.
                        if event.detail?        then ev.detail          = event.detail
                        if event.screenX?       then ev.screenX         = event.screenX
                        if event.screenY?       then ev.screenY         = event.screenY
                        if event.clientX?       then ev.clientX         = event.clientX
                        if event.clientY?       then ev.clientY         = event.clientY
                        if event.ctrlKey?       then ev.ctrlKey         = event.ctrlKey
                        if event.altKey?        then ev.altKey          = event.altKey
                        if event.shiftKey?      then ev.shiftKey        = event.shiftKey
                        if event.metaKey?       then ev.metaKey         = event.metaKey
                        if event.button?        then ev.button          = event.button
                        if event.relatedTarget? then ev.relatedTarget   = event.relatedTarget.__nodeID
                        if event.modifiersList? then ev.modifiersList   = event.modifiersList
                        if event.deltaX?        then ev.deltaX          = event.deltaX
                        if event.deltaY?        then ev.deltaY          = event.deltaY
                        if event.deltaZ?        then ev.deltaZ          = event.deltaZ
                        if event.deltaMode?     then ev.deltaMode       = event.deltaMode
                        if event.data?          then ev.data            = event.data
                        if event.inputMethod?   then ev.inputmethod     = event.inputMethod
                        if event.locale?        then ev.locale          = event.locale
                        if event.char?          then ev.char            = event.char
                        if event.key?           then ev.key             = event.key
                        if event.location?      then ev.location        = event.location
                        if event.modifiersList? then ev.modifiersList   = event.modifiersList
                        if event.repeat?        then ev.repeat          = event.repeat

                        console.log "Sending event:"
                        console.log ev

                        remote.processEvent(ev)
                        return false
        )

    if test_env == true
        dnodeConnection.connect(3002)
    else
        #TODO: this is where we'd add reconnect param.
        dnodeConnection.connect()

    printMethodCall = (node, method, args, rvID) ->
        args = nodes.scrub(args)
        nodeName = node.name || node.nodeName
        argStr = ""
        for arg in args
            argStr += "#{arg}, "
        argStr = argStr.replace(/,\s$/, '')
        console.log "#{rvID} = #{nodeName}.#{method}(#{argStr})"

    printCommand = (cmd) ->
        method = cmd['method']
        params = cmd['params']
        str = 'Exec: ' + method + '('
        for p in params
            if (params.hasOwnProperty(p))
                str += p + ' => ' + params[p] + ","
        str = str.replace(/,$/, ''); #TODO: not this.
        str += ')'
        console.log(str)

