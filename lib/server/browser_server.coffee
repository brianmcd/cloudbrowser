EventProcessor       = require('./browser/event_processor') # TODO move this
TaggedNodeCollection = require('../shared/tagged_node_collection')
Browser              = require('./browser')
{serialize}          = require('./browser/dom/serializer')

#   TODO: where should resourceproxy live?
#       Maybe here instead of Browser?

# Serves 1 Browser to n clients.
class BrowserServer
    constructor : (opts) ->
        @id = opts.id
        @browser = new Browser(opts.id, opts.shared)
        @sockets = []
        @nodes = new TaggedNodeCollection()
        @events = new EventProcessor(this)

        # Indicates whether @browser is currently loading a page.
        # If so, we don't process client events/updates.
        @browserLoading = false

        for own event, handler of DOMEventHandlers
            do (event, handler) =>
                @browser.on event, () =>
                    handler.apply(this, arguments)

        # TODO:
        #   'log'
        #   bandwidth measuring and logging etc should go here, since browser is protocol agnostic.
    
    broadcastEvent : (name, params) ->
        for socket in @sockets
            socket.emit(name, params)

    addSocket : (socket) ->
        cmds = serialize(@browser.window.document, @browser.resources)
        socket.emit 'loadFromSnapshot'
            nodes : cmds
            events : @events.getSnapshot()
            components : @browser.getSnapshot().components
        @sockets.push(socket)
        socket.on 'processEvent', @processEvent
        socket.on 'setAttribute', @processClientSetAttribute
        socket.on 'disconnect', () =>
            @sockets = (s for s in @sockets when s != socket)

    processEvent : (args ) =>
        if !@browserLoading
            @broadcastEvent 'pauseRendering'
            @events.processEvent(args)
            @broadcastEvent 'resumeRendering'

    processClientSetAttribute : (args) =>
        if !@browserLoading
            target = @nodes.get(args.target)
            {attribute, value} = args
            if attribute == 'src'
                return
            if attribute == 'selectedIndex'
                return target[attribute] = value
            target.setAttribute(attribute, value)

# The BrowserServer constructor iterates over the properties in this object and
# adds an event handler to the Browser for each one.  The function name must
# match the Browser event name.  'this' is set to the Browser via apply.
DOMEventHandlers =
    DOMStyleChanged : (event) ->
        @broadcastEvent 'changeStyle',
            target : event.target.__nodeID
            attribute : event.attribute
            value : event.value

    DOMPropertyModified : (event) ->
        @broadcastEvent 'setProperty',
            target   : event.target.__nodeID
            property : event.property
            value    : event.value

    DocumentCreated : (event) ->
        @nodes.add(event.target)

    # Tag all newly created nodes.
    # This seems cleaner than having serializer do the tagging.
    DOMNodeInserted : (event) ->
        if event.target.tagName != 'SCRIPT' &&
           event.target.parentNode.tagName != 'SCRIPT' &&
           !event.target.__nodeID
            @nodes.add(event.target)

    DOMCharacterDataModified : (event) ->
        @broadcastEvent 'setCharacterData',
            target : event.target.__nodeID
            value  : event.target.nodeValue

    DOMNodeInsertedIntoDocument : (event) ->
        if event.target.tagName != 'SCRIPT' && event.target.parentNode.tagName != 'SCRIPT'
            node = event.target
            cmds = serialize(node, @browser.resources)
            # 'before' tells the client where to insert the top level node in
            # relation to its siblings.
            # We only need it for the top level node because nodes in its tree
            # are serialized in order.
            before = node.nextSibling
            while before?.tagName?.toLowerCase() == 'script'
                before = before.nextSibling
            cmds[0].before = before?.__nodeID
            @broadcastEvent 'attachSubtree', cmds

    DOMNodeRemovedFromDocument : (event) ->
        if event.target.tagName != 'SCRIPT' && event.relatedNode.tagName != 'SCRIPT'
            @broadcastEvent 'removeSubtree',
                parent : event.relatedNode.__nodeID
                node   : event.target.__nodeID

    DOMAttrModified : (event) ->
        # Note: ADDITION can really be MODIFIED as well.
        if event.attrChange == 'ADDITION'
            @broadcastEvent 'setAttr',
                target : event.target.__nodeID
                name   : event.attrName
                value  : event.newValue
        else
            @broadcastEvent 'removeAttr',
                target : event.target.__nodeID
                name   : event.attrName

    EnteredTimer : () ->
        @broadcastEvent 'pauseRendering'

    ExitedTimer : () ->
        @broadcastEvent 'resumeRendering'

    PageLoading : () ->
        @browserLoading = true

    PageLoaded : () ->
        @browserLoading = false
        cmds = serialize(@browser.window.document, @browser.resources)
        events = @events.getSnapshot()
        components = @browser.getSnapshot().components
        for socket in @sockets
            socket.emit 'loadFromSnapshot'
                nodes      : cmds
                events     : events
                components : components

    WindowMethodCalled : (event) ->
        @broadcastEvent 'callWindowMethod',
            method : event.method
            args : event.args

module.exports = BrowserServer
