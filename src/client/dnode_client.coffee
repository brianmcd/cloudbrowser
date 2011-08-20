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
        @loadFromSnapshot = (snapshot) ->
            node = null
            for record in snapshot
                switch record.type
                    when 'document'
                        if record.parent
                            target = nodes.get(record.parent)
                            nodes.add(target.contentDocument, record.id)
                        else
                            nodes.add(document, record.id)
                    when 'comment'
                        if record.ownerDocument
                            doc = nodes.get(record.ownerDocument)
                            node = doc.createComment(record.value)
                        else
                            node = document.createComment(record.value)
                        nodes.add(node, record.id)
                        parent = nodes.get(record.parent)
                        parent.appendChild(node)
                    when 'element'
                        if record.ownerDocument
                            doc = nodes.get(record.ownerDocument)
                            node = doc.createElement(record.name)
                        else
                            node = document.createElement(record.name)
                        for name, value of record.attributes
                            node.setAttribute(name, value)
                        nodes.add(node, record.id)
                        parent = nodes.get(record.parent)
                        parent.appendChild(node)
                    when 'text'
                        if record.ownerDocument
                            doc = nodes.get(record.ownerDocument)
                            node = doc.createTextNode(record.value)
                        else
                            node = document.createTextNode(record.value)
                        nodes.add(node, record.id)
                        parent = nodes.get(record.parent)
                        parent.appendChild(node)

        @tagDocument = (params) ->
            parent = nodes.get(params.parent)
            nodes.add(parent.contentDocument, params.id)

        # Params:
        #   'method'
        #   'rvID'
        #   'targetID'
        #   'args'
        @DOMUpdate = (params) ->
            processInstruction = (inst) ->
                target = nodes.get(inst.targetID)
                method = inst.method
                rvID = inst.rvID
                args = nodes.unscrub(inst.args)

                if target[method] == undefined
                    throw new Error("Tried to process an invalid method: #{method}")

                rv = target[method].apply(target, args)

                if rvID?
                    if !rv?
                        throw new Error('expected return value')
                    else if rv.__nodeID?
                        if rv.__nodeID != rvID
                            throw new Error "id issue"
                    else
                        nodes.add(rv, rvID)

                #printMethodCall(target, method, args, rvID)
            if params instanceof Array
                for inst in params
                    processInstruction(inst)
            else
                processInstruction(params)

        # The serializer only uses methods to construct the DOM, so we don't
        # need to worry about handling an Array here.
        @DOMPropertyUpdate = (params) ->
            target = nodes.get(params.targetID)
            prop = params.prop
            value = params.value
            if /^node\d+$/.test(value)
                value = nodes.unscrub(value)
            return target[prop] = value

        @clear = () ->
            while document.hasChildNodes()
                document.removeChild(document.firstChild)
            nodes = new TaggedNodeCollection()
            if test_env
                window.__nodes = nodes
            delete document.__nodeID

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

