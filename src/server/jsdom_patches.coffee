exports.applyPatches = (core) ->
    addDefaultHandlers(core)
    fixDocumentClose(core)

addDefaultHandlers = (core) ->
    core.HTMLAnchorElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside default click handler"
            window = event.target.ownerDocument.parentWindow
            window.location = event.target.href if event.target.href?
    core.HTMLInputElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside overridden click handler"
            event.target.click()
    
fixDocumentClose = (core) ->
    core.HTMLDocument.prototype.close = ->
        @_queue.resume()
        f = core.resourceLoader.enqueue this, ->
            @readyState = 'complete'
            ev = @createEvent('HTMLEvents')
            ev.initEvent('DOMContentLoaded', false, false)
            @dispatchEvent(ev)
            ev = @createEvent('HTMLEvents')
            ev.initEvent('load', false, false)
            @defaultView.dispatchEvent(ev)
        f(null, true)
