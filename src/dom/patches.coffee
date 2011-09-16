patchEvents = require('./event_patches').patchEvents

exports.applyPatches = (level3) ->
    addDefaultHandlers(level3.core)
    patchEvents(level3)
    patchScriptTag(level3)

patchScriptTag = (level3) ->
    core = level3.core
    html = level3.html
    # TODO: Copied from zombie - we should do somethign cleaner, this is just for testing.
    core.CharacterData.prototype.__defineSetter__ "_nodeValue", (newValue) ->
        oldValue = @_text || ""
        @_text = newValue
        if @ownerDocument && @parentNode
            ev = @ownerDocument.createEvent("MutationEvents")
            ev.initMutationEvent("DOMCharacterDataModified", true, false, this, oldValue, newValue, null, null)
            @dispatchEvent ev
    core.CharacterData.prototype.__defineGetter__ "_nodeValue", -> @_text
    html.HTMLScriptElement._init = () ->
        this.addEventListener 'DOMNodeInsertedIntoDocument', () ->
          if this.src
            core.resourceLoader.load(this, this.src, this._eval)
          else
            src = this.sourceLocation || {}
            filename = src.file || this._ownerDocument.URL

            if src
              filename += ':' + src.line + ':' + src.col
            filename += '<script>'

            if this.text
                console.log('enqueuing inline script: ')
                console.log(this.text)
                console.log(this)
                core.resourceLoader.enqueue(this, this._eval, filename)(null, this.text)
            else
                # TODO
                # Issues:
                #   This doesn't hold its place in the resourcequeue, so onload fires before the script is loaded.
                this.addEventListener 'DOMCharacterDataModified', (event) ->
                    console.log('inside DOMChar')
                    console.log('enqueuing inline script: ')
                    console.log(this.text)
                    console.log('end enqueed script')
                    core.resourceLoader.enqueue(this, this._eval, filename)(null, this.text)

addDefaultHandlers = (core) ->
    core.HTMLAnchorElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside default click handler"
            window = event.target.ownerDocument.parentWindow
            window.location = event.target.href if event.target.href?
    ###
    core.HTMLInputElement.prototype._eventDefaults =
        click : (event) ->
            console.log "Inside overridden click handler"
            #TODO: bring this back, but just double check things.
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
        ###
    core.HTMLButtonElement.prototype._eventDefaults =
        # looks like this already is done for input
        click : (event) ->
            elem = event.target
            console.log('Inside click handler for button')
            # Clicks on submit buttons should generate a submit event on the
            # enclosing form.
            if elem.type == 'submit'
                form =  elem.form
                console.log("Generating a submit event from button click")
                ev = elem.ownerDocument.createEvent('HTMLEvents')
                ev.initEvent('submit', false, true)
                form.dispatchEvent(ev)
                form.reset()

