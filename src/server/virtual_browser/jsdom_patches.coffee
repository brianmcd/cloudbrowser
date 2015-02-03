Util = require('util')

debug = require('debug')
logger = debug("cloudbrowser:jsdompatch")

exports.applyPatches = () ->
    jsdom = require('jsdom').dom
    html = jsdom
    events = jsdom
    core = jsdom
    addDefaultHandlers(html)
    addKeyboardEvents(core, events)
    patchScriptTag(html)
    addCustomCssPropertySupport('cloudbrowserRelativePosition', html.CSSStyleDeclaration)

patchScriptTag = (html) ->
    html.languageProcessors =
        javascript : (element, code, filename) ->
            window = element.ownerDocument?.parentWindow
            if window?
                try
                    window.run(code, filename)
                catch e
                    # TODO: log this based on debug flag.
                    logger(e.stack)
                    # TODO: JSDOM swallows this exception.
                    element.raise(
                        'error', 'Running ' + filename + ' failed.',
                        {error: e, filename: filename}
                    )

addDefaultHandlers = (html) ->
    html.HTMLAnchorElement.prototype._eventDefaults =
        click : (event) ->
            #console.log "Inside ANCHOR click handler"
            #console.log(event.target.tagName)
            window = event.target.ownerDocument.parentWindow
            #console.log("event.target.href:" + event.target.href)
            window.location = event.target.href if event.target.href?

    # See http://dev.w3.org/html5/spec/single-page.html#interactive-content
    # and http://dev.w3.org/html5/spec/single-page.html#checkbox-state-(type=checkbox)
    html.HTMLInputElement.prototype._preActivationHandlers.click = () ->
        target = this
        if target.type == 'checkbox'
            target._oldchecked = target.checked
            target.checked = !target.checked
        else if target.type == 'radio'
            doc = target.ownerDocument
            others = doc.getElementsByName(target.name)
            for other in others
                if other != target && other.type == 'radio'
                    other.checked = false
            target._oldchecked = target.checked
            target.checked = true

    html.HTMLInputElement.prototype._eventDefaults.click = (event) ->
        #console.log "Inside INPUT new click handler"
        target = event.target
        if target.type == 'submit'
            form = target.form
            if form
              form._dispatchSubmitEvent()

    html.HTMLInputElement.prototype._canceledActivationHandlers.click = (event) ->
        target = event.target
        if target.type == 'checkbox'
            target._checked = target._oldchecked
        else if target.type == 'radio'
            target._checked = target._oldchecked
            # at this point all other radio buttons in that group are false
            # which seems to be what the spec wants; we don't attempt to
            # restore their original values

    html.HTMLButtonElement.prototype._eventDefaults =
        # looks like this already is done for input
        click : (event) ->
            #console.log('Inside BUTTON click handler')
            elem = event.target
            # Clicks on submit buttons should generate a submit event on the
            # enclosing form.
            if elem.type == 'submit'
                form =  elem.form
                #console.log("Generating a submit event from button click")
                ev = elem.ownerDocument.createEvent('HTMLEvents')
                ev.initEvent('submit', false, true)
                form.dispatchEvent(ev)
                form.reset()

    html.HTMLButtonElement.prototype.click = () ->
        #console.log("Inside BUTTON overridden click() method")
        ev = @_ownerDocument.createEvent('HTMLEvents')
        ev.initEvent('click', true, true)
        @dispatchEvent(ev)



# Note: the actual KeyboardEvent implementation in browsers seems to vary
# widely, so part of our job will be to convert from the events coming in
# to this level 3 event implementation.
#
# http://dev.w3.org/2006/webapi/DOM-Level-3-Events/html/DOM3-Events.html
addKeyboardEvents = (core, events) ->

    events.KeyboardEvent = (eventType) ->
        events.UIEvent.call(this, eventType)
        # KeyLocationCode
        @DOM_KEY_LOCATION_STANDARD = 0
        @DOM_KEY_LOCATION_LEFT     = 1
        @DOM_KEY_LOCATION_RIGHT    = 2
        @DOM_KEY_LOCATION_NUMPAD   = 3
        @DOM_KEY_LOCATION_MOBILE   = 4
        @DOM_KEY_LOCATION_JOYSTICK = 5

        @char     = null
        @key      = null
        @location = null
        @repeat   = null
        @locale   = null

        # Set up getters/setters for keys that are properties.
        ['ctrlKey', 'shiftKey', 'altKey', 'metaKey'].forEach (key) =>
            prop = "_#{key}"
            this[prop] = false
            # TODO: put these on proto
            this.__defineSetter__ key, (val) ->
                return this[prop] = val
            this.__defineGetter__ key, () ->
                return this[prop]

        # Set up hidden properties for keys that are queryable via getModifierState,
        # but are not public properties.
        for key in ['_altgraphKey', '_capslockKey', '_fnKey', '_numlockKey',
                    '_scrollKey', '_symbollockKey', '_winKey']
            this[key] = false

        return undefined

    events.KeyboardEvent.prototype =
        initKeyboardEvent : (typeArg, canBubbleArg, cancelableArg, viewArg
                            , charArg, keyArg, locationArg, modifiersListArg
                            , repeat, localeArg) ->
            @initUIEvent(typeArg, canBubbleArg, cancelableArg, viewArg)
            @char     = charArg
            @key      = keyArg
            @location = locationArg
            @repeat   = repeat
            @locale   = localeArg

            if modifiersListArg
                modifiers = modifiersListArg.split(' ')
                current = null
                while current = modifiers.pop()
                    current = current.toLowerCase()
                    prop = "_#{current}Key"
                    if this[prop] != undefined
                        this[prop] = true

        getModifierState : (keyIdentifierArg) ->
            lookupStr = "_#{keyIdentifierArg}Key"
            if this[lookupStr] != undefined
                return this[lookupStr]
            return false
        # TODO: initKeyboardEventNS
    events.KeyboardEvent.prototype.__proto__ = events.UIEvent.prototype

    core.Document.prototype.createEvent = (eventType) ->
        switch eventType
            when "MutationEvents", "MutationEvent"
                return new events.MutationEvent(eventType)
            when "UIEvents", "UIEvent"
                return new events.UIEvent(eventType)
            when "MouseEvents", "MouseEvent"
                return new events.MouseEvent(eventType)
            when "HTMLEvents", "HTMLEvent"
                return new events.Event(eventType)
            when "KeyboardEvents", "KeyboardEvent"
                return new events.KeyboardEvent(eventType)
        return new events.Event(eventType)

addCustomCssPropertySupport = (property, CSSStyleDeclaration) ->
    propertyName = "-" + property.replace /([a-z]+)([A-Z])/g, (match, p1, p2) ->
        return "#{p1}-#{p2.toLowerCase()}"
    Object.defineProperty CSSStyleDeclaration.prototype, property,
        get: ->
            @getPropertyValue(propertyName)
        set: (value) ->
            @setProperty(propertyName, value)
