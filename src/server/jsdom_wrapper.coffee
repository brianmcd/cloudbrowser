TaggedNodeCollection = require('../shared/tagged_node_collection')
EventEmitter = require('events').EventEmitter

# JSDOMWrapper.jsdom returns the wrapped JSDOM object.
# Adds advice and utility methods.
class JSDOMWrapper extends EventEmitter
    constructor : (browser) ->
        @browser = browser
        @nodes = new TaggedNodeCollection()
        @clearRequireCache()
        @jsdom = require('jsdom')
        @jsdom.defaultDocumentFeatures =
            FetchExternalResources : ['script']#, 'img', 'css', 'frame', 'link'] #TODO: activate the rest
            ProcessExternalResources : ['script']#, 'frame', 'iframe'] # TODO:
            MutationEvents : '2.0'
            QuerySelector : false
        @wrapDOMMethods(@jsdom.dom.level3.html)

    # Clear JSDOM out of the require cache.  We have to do this because
    # we modify JSDOM's internal data structures with per-BrowserInstance
    # specifiy information, so we need to get a whole new JSDOM instance
    # for each BrowserInstance.  require() caches the objects it returns,
    # so we need to remove those objects from the cache to force require
    # to give us a new object each time.
    clearRequireCache : ->
        reqCache = require.cache
        for entry of reqCache
            if entry.match(/jsdom/) || entry.match(/forms/) ||
               entry.match(/xpath/) || entry.match(/history/) ||
               entry.match(/eventloop/) || entry.match(/window_context/)
                console.log "Deleting #{entry}"
                delete reqCache[entry]

    wrapMethod : (parent, method) ->
        console.log "Wrapping #{method}"
        oldStr = method + '__original'
        originalMethod = if parent[oldStr] then parent[oldStr] else parent[oldStr] = parent[method]
        nodes = @nodes
        self = this
        parent[method] = ->
            console.log "#{method} called"
            #TODO: I don't think I need to convert to array anymore
            args = Array.prototype.slice.call(arguments)
            rv = originalMethod.apply(this, args)

            if self.isDOMNode(rv) && rv[nodes.propName] == undefined
                nodes.add(rv)
            
            params =
                targetID : this[nodes.propName]
                rvID : rv[nodes.propName]
                method : method
                args : nodes.scrub(args)
            self.emit 'DOMUpdate', params
            #printMethodCall(this, method, args)
            return rv

    isDOMNode : (node) ->
        (typeof node.ELEMENT_NODE == 'number') &&
                      (node.ELEMENT_NODE == 1) &&
                      (node.ATTRIBUTE_NODE == 2)

    # BIG TODO FIXME XXX : Add wrappers for mutators like nodeValue() etc
    wrapDOMMethods : (dom) ->
        wrapper = (info) =>
            obj = info[0]
            methods = info[1]
            for method in methods
                @wrapMethod(obj, method)
        [[dom.Node.prototype, ['insertBefore', 'replaceChild',
                               'appendChild', 'removeChild']],
        [dom.Element.prototype, ['setAttribute', 'removeAttribute',
                                 'setAttributeNode', 'removeAttributeNode']],
        [dom.Document.prototype, ['createElement', 'createTextNode',
                                  'createDocumentFragment', 'createComment',
                                  'createAttribute']]].forEach(wrapper)

    printMethodCall : (node, method, args) ->
        parentName = node.name || node.tagName
        if node.nodeType == 9  # DOCUMENT_NODE
            parentName = '#document'
        argStr = ""
        for arg in args
            if args.replace # ?
                # If we're working with a string, escape newlines
                arg = "'" + arg.replace(/\r\n/, "\\r\\n") + "'"
            else if args.data
                # If we're dealing with comments or text, escape newline and
                # add ''s
                arg = "'" + args.data.replace(/\r\n/, "\\r\\n") + "'"
            else if typeof arg == 'object'
                arg = arg[@nodes.propName] || arg.name || arg.tagName
            argStr += arg + ' '
        argStr = argStr.replace(/\s$/, '')
        console.log(parentName + '.' + method + '(' + argStr + ')')

module.exports = JSDOMWrapper
