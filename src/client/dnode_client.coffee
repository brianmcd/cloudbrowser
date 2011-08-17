DNode = require('dnode')
TaggedNodeCollection = require('./tagged_node_collection')

module.exports = (window, document) ->
    nodes = new TaggedNodeCollection()

    dnodeConnection = DNode( (remote, conn) ->
        console.log "Connecting to server..."
        conn.on('ready', () ->
            console.log "Connection is ready"
            console.log(remote)
            remote.auth(window.__envSessionID)
        )

        # Params:
        #   'method'
        #   'rvID'
        #   'targetID'
        #   'args'
        #TODO: Need to have a "batch proces function".  Need to add "TagDocument"
        # TODO: clear needs to be able to be called on a certain document.
        @DOMUpdate = (params) ->
            console.log(params)
            processInstruction = (inst) ->
                # SPECIAL CASE
                # TODO: this is a quick hack.
                # TODO: need to add a DNode endpoint that takes batch instructions and calls DOMUpdate/DOMPropertyUpdate/clear correctly.
                if inst.method == 'tagDocument'
                    if inst.targetID == null
                        nodes.add(window.document, inst.args[0])
                    else
                        target = nodes.get(inst.targetID)
                        nodes.add(target.contentDocument, inst.args[0])
                        # TODO THIS IS A HACK
                        doc = target.contentDocument
                        while doc.hasChildNodes()
                            doc.removeChild(doc.firstChild)
                    return

                target = nodes.get(inst.targetID)
                method = inst.method
                rvID = inst.rvID
                args = nodes.unscrub(inst.args)

                if target[method] == undefined
                    throw new Error "Tried to process an invalid method: #{method}"

                try
                    rv = target[method].apply(target, args)
                catch e
                    console.log e
                    throw e

                if rv == undefined
                    return

                if rv.__nodeID && rvID && (rv.__nodeID != rvID)
                    throw new Error "id issue"
                if rvID? && /^node\d+$/.test(rvID)
                    if rv.__nodeID == undefined
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

    if process?.env?.TESTS_RUNNING
        console.log("Running DNode over TCP")
        dnodeConnection.connect(3002)
    else
        #TODO: this is where we'd add reconnect param.
        console.log("Running DNode over socket.io")
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

