class Slider
    # node - the dom node that this component will be rendered into.
    # opts - sent by server, this should be the options object to
    #         pass to slider constructor.
    constructor : (socket, node, opts) ->
        # TODO: something nicer here...maybe make server have it.
        $(node).addClass('yui3-skin-sam')
        @socket = socket
        @node = node
        self = this
        @injectYUI () ->
            YUI().use 'slider', (Y) ->
                console.log("slider opts:")
                console.log(opts)
                slider = new Y.Slider(opts)
                # TODO: can I register on '*'?
                #       I don't think so, but I can pass multiple event names.
                slider.on 'valueChange', self.forwardEvent
                slider.render(node)

    forwardEvent : (event) =>
        sanitized = {}
        for own key, val of event
            if typeof val != 'function' && typeof val != 'object'
                sanitized[key] = val
        @socket.emit 'componentEvent',
            nodeID : @node.__nodeID
            event : sanitized

    injectYUI : (callback) ->
        scripts = document.getElementsByTagName('script')
        for script in scripts
            if script.src = 'http://yui.yahooapis.com/3.4.1/build/yui/yui-min.js'
                # ISSUE TODO: This breaks if the script has already loaded.
                return script.addEventListener 'load', callback
        script = document.createElement('script')
        script.src = 'http://yui.yahooapis.com/3.4.1/build/yui/yui-min.js'
        document.getElementsByTagName('head')[0].appendChild(script)
        script.addEventListener 'load', callback

module.exports = Slider
