# Intercepts client side events and sends them to the server for processing.
class EventMonitor
    constructor : (document, remote) ->
        ###
        MouseEvents = ['click', 'mousedown', 'mouseup', 'mouseover',
                       'mouseout', 'mousemove']
        ###
        MouseEvents = ['click']
        # Note: change is not a standard DOM event, but is supported by all
        # the browsers.
        #UIEvents = ['change', 'DOMFocusIn', 'DOMFocusOut', 'DOMActivate']
        UIEvents = ['change']
        HTMLEvents = [] #'submit', 'select', 'change', 'reset', 'focus', 'blur',
        #              'resize', 'scroll']
        [MouseEvents, HTMLEvents, UIEvents].forEach (group) ->
            group.forEach (eventType) ->
                document.addEventListener eventType, (event) ->
                    if eventType == 'click'
                        console.log "#{event.type} #{event.target.__nodeID}"
                    event.stopPropagation()
                    event.preventDefault()
                    ev = {}
                    if eventType == 'change'
                        # The change event doesn't normally have the new
                        # data attached, so we snag it.
                        ev.data = event.target.value
                    ev.target = event.target.__nodeID
                    ev.type = event.type
                    ev.bubbles = event.bubbles
                    ev.cancelable = event.cancelable # TODO: if this is no...what's that mean happened on client?
                    ev.view = null # TODO look into this.
                    # TODO: see if we can make this work by just copying all
                    # string properties over in a loop
                    if event.detail?        then ev.detail          = event.detail
                    if event.screenX?       then ev.screenX         = event.screenX
                    if event.screenY?       then ev.screenY         = event.screenY
                    if event.clientX?       then ev.clientX         = event.clientX
                    if event.clientY?       then ev.clientY         = event.clientY
                    if event.ctrlKey?       then ev.ctrlKey         = event.ctrlKey
                    if event.altKey?        then ev.altKey          = event.altKey
                    if event.shiftKey?      then ev.shiftKey        = event.shiftKey
                    if event.metaKey?       then ev.metaKey         = event.metaKey
                    if event.button?        then ev.button          = event.button
                    if event.relatedTarget? then ev.relatedTarget   = event.relatedTarget.__nodeID
                    if event.modifiersList? then ev.modifiersList   = event.modifiersList
                    if event.deltaX?        then ev.deltaX          = event.deltaX
                    if event.deltaY?        then ev.deltaY          = event.deltaY
                    if event.deltaZ?        then ev.deltaZ          = event.deltaZ
                    if event.deltaMode?     then ev.deltaMode       = event.deltaMode
                    if event.data?          then ev.data            = event.data
                    if event.inputMethod?   then ev.inputmethod     = event.inputMethod
                    if event.locale?        then ev.locale          = event.locale
                    if event.char?          then ev.char            = event.char
                    if event.key?           then ev.key             = event.key
                    if event.location?      then ev.location        = event.location
                    if event.modifiersList? then ev.modifiersList   = event.modifiersList
                    if event.repeat?        then ev.repeat          = event.repeat

                    console.log "Sending event:"
                    console.log ev

                    remote.processEvent(ev)
                    return false

module.exports = EventMonitor
