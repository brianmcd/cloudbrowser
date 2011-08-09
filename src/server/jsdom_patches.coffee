exports.applyPatches = (core) ->
    addDefaultHandlers(core)

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
