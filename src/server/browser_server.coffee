TaggedNodeCollection = require('../shared/tagged_node_collection')
Browser              = require('./browser')
{serialize}          = require('./browser/dom/serializer')

# TODO
#   Where does snapshot live?  That should be here, right?  A DOM traversal on the Browser.
#   This class could use helpers that give some utilities for traversing the DOM.
#
#   TODO: where should resourceproxy live?
#       Maybe here instead of Browser?

# Serves the Browser to n clients.
class BrowserServer
    constructor : (opts) ->
        @id = opts.id
        @browser = new Browser(opts.id, opts.shared)
        @sockets = []
        @nodes = new TaggedNodeCollection()

        ['DOMNodeInserted',
         'DOMNodeInsertedIntoDocument',
         'DOMNodeRemovedFromDocument',
         'DOMAttrModified',
         'DocumentCreated'].forEach (event) =>
             @browser.on event, @["handle#{event}"]

        # TODO:
        #   'log'
        #   bandwidth measuring and logging etc should go here, since browser is protocol agnostic.
        #   some sort of page load event so we can resync.
        #       this should be 2 events:
        #           'pageLoading' - stop client updates and event processing
        #           'pageLoaded' - resumse

    addSocket : (socket) ->
        console.log("ADDING A SOCKET")
        cmds = serialize(@browser.window.document, @browser.resources)
        bsnapshot = @browser.getSnapshot()
        socket.emit 'loadFromSnapshot'
            nodes : cmds
            events : bsnapshot.events
            components : bsnapshot.components
        @sockets.push(socket)
        # TODO: handle disconnection

    handleDocumentCreated : (event) =>
        @nodes.add(event.target)

    # Tag all newly created nodes.
    # This seems cleaner than having serializer do the tagging.
    # TODO: this won't tag the document node.
    handleDOMNodeInserted : (event) =>
        console.log "DOMNodeInserted: #{event.target}"
        if !event.target.__nodeID
            @nodes.add(event.target)

    # TODO: How can we handle removal/re-insertion efficiently?
    # TODO: what if serialization starts at an iframe?
    handleDOMNodeInsertedIntoDocument : (event) =>
        @broadcastEvent 'attachSubtree',
            parent  : event.relatedNode.__nodeID
            subtree : serialize(event.target, @browser.resources)

    handleDOMNodeRemovedFromDocument : (event) =>
        @broadcastEvent 'removeSubtree',
            parent : event.relatedNode.__nodeID
            node   : event.target.__nodeID

    # TODO: we want client to set these using properties, should we do
    #       the conversion from attribute name to property name here or on
    #       client?
    handleDOMAttrModified : (event) =>
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
            
    broadcastEvent : (name, params) ->
        for socket in @sockets
            socket.emit(name, params)

module.exports = BrowserServer
