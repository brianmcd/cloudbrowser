patchEvents = require('./event_patches').patchEvents

exports.applyPatches = (level3) ->
    addDefaultHandlers(level3.core)
    patchEvents(level3)

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
        keypress : (event) ->
            # TODO: delete/backspace etc
            # is there a way to just 'apply' the key value to the string?
            # look at string methods.
            elem = event.target
            #console.log(event)
            if !elem.value
                elem.value = event.char
            else
                elem.value += event.char
            console.log(elem.value)
