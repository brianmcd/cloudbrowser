TaggedNodeCollection = require('../shared/tagged_node_collection')
EventEmitter = require('events').EventEmitter

# JSDOMWrapper.jsdom returns the wrapped JSDOM object.
# Adds advice and utility methods.
class JSDOMWrapper extends EventEmitter
    constructor : (browser) ->
        @browser = browser
        @nodes = new TaggedNodeCollection()
        # Clear JSDOM out of the require cache.  We have to do this because
        # we modify JSDOM's internal data structures with per-BrowserInstance
        # specifiy information, so we need to get a whole new JSDOM instance
        # for each BrowserInstance.  require() caches the objects it returns,
        # so we need to remove those objects from the cache to force require
        # to give us a new object each time.
        reqCache = require.cache
        for entry of reqCache
            # Note: when we were using zombie, we had to clear out a lot more.
            # As we re-add some zombie features, they might need to be cleared.
            if /jsdom/.test(entry) && !/jsdom_wrapper/.test(entry)
                console.log "Deleting #{entry}"
                delete reqCache[entry]
        @jsdom = require('jsdom')
        @jsdom.defaultDocumentFeatures =
            FetchExternalResources : ['script']#, 'img', 'css', 'frame', 'link'] #TODO: activate the rest
            ProcessExternalResources : ['script']#, 'frame', 'iframe'] # TODO:
            MutationEvents : '2.0'
            QuerySelector : false
        @wrapDOMMethods(@jsdom.dom.level3.html)
        @addDefaultHandlers(@jsdom.dom.level3.core)
        @setLanguageProcessor(@jsdom.dom.level3.core)

    addDefaultHandlers : (core) ->
        browser = @browser
        core.HTMLAnchorElement.prototype._eventDefaults =
            click : (event) ->
                url = event.target.href
                if url
                    if /jsdom_wrapper/.test(browser.window.location)
                        url = "http://localhost:3001" + url
                    browser.load url

    setLanguageProcessor : (core) ->
        core.languageProcessors =
            javascript : (element, code, filename) ->
                window = element.ownerDocument.parentWindow
                try
                    console.log "Evaluating: #{code}"
                    window._evaluate code, filename
                    console.log "Script succeeded"
                catch e
                    console.log "Script failed: #{e}"

    # Manually testing this with innerHTML for now.
    # There is also some special case code in the client side
    wrapDOMGettersSetters : (dom) ->
        nodes = @nodes
        propName = @nodes.propName
        self = this
        old = dom.Element.prototype.__lookupSetter__ 'innerHTML'
        dom.Element.prototype.__defineSetter__ 'innerHTML', (html) ->
            rv = old.call this, html
            params =
                targetID : this[propName]
                rvID : null
                method : 'innerHTML'
                args : [html]
            self.emit 'DOMUpdate', params
            return rv

    # BIG TODO FIXME XXX : Add wrappers for mutators like nodeValue() etc
    wrapDOMMethods : (dom) ->
        isDOMNode = (node) ->
            (typeof node.ELEMENT_NODE == 'number') &&
            (node.ELEMENT_NODE == 1)               &&
            (node.ATTRIBUTE_NODE == 2)

        nodes = @nodes
        propName = @nodes.propName
        self = this

        wrapper = (info) ->
            parent = info[0]
            methods = info[1]
            for method in methods
                do (parent, method) ->
                    console.log "Wrapping #{method}"
                    oldStr = method + '__original'
                    originalMethod = if parent[oldStr] then parent[oldStr] else parent[oldStr] = parent[method]
                    parent[method] = ->
                        rv = originalMethod.apply(this, arguments)
                        if isDOMNode(rv) && rv[propName] == undefined
                            nodes.add(rv)
                        params =
                            targetID : this[propName]
                            rvID : rv[propName]
                            method : method
                            args : nodes.scrub(arguments)
                        self.emit 'DOMUpdate', params
                        #printMethodCall(this, method, argumentss)
                        return rv

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
