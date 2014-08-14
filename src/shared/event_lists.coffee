# These are events we listen on even if they aren't requested, because
# the server needs to know about them no matter what.  They may also be
# here to prevent the default action of the client's browser.
exports.defaultEvents =
    'click'  : true
    'change' : true

# These are events that are eligible for listening on the client.  We need
# this because we need to know which events we should ignore inside our
# addEventListener advice.
exports.clientEvents =
    'click'       : true
    'change'      : true
    'blur'        : true
    'DOMFocusIn'  : true
    'DOMFocusOut' : true
    'focus'       : true
    'focusin'     : true
    'focusout'    : true
    'dblclick'    : true # TODO: does our capturing click prevent dblclicks?
    'mousedown'   : true
    'mouseenter'  : true
    'mouseleave'  : true
    'mousemove'   : true
    'mouseover'   : true
    'mouseout'    : true
    'mouseup'     : true
    'mousewheel'  : true
    'keydown'     : true
    'keypress'    : true
    'keyup'       : true
    'select'      : true
    'submit'      : true
    #'scroll'
    #'resize'
    #'select'
    #'wheel'
    # HTMLEvents
    #'drag' - we could echo this to all clients. also dragend etc
    #'input' - what's this?

groups =
    'UIEvents' : [
        'DOMActivate'
        'DOMFocusIn'
        'DOMFocusOut'
        'select'
        'resize'
        'scroll'
    ]
    'MouseEvents' : [
        'click'
        'dblclick'
        'mousedown'
        'mouseenter'
        'mouseleave'
        'mousemove'
        'mouseout'
        'mouseover'
        'mouseup'
        'mousewheel'
    ]
    'TextEvent' : [
        'textinput'
    ]
    'KeyboardEvent' : [
        'keydown'
        'keypress'
        'keyup'
    ]
    'HTMLEvents' : [
        'change'
        'blur'
        'focus'
        'submit'
        'select'
        'focusin'
    ]

# Maps an event type (like 'click') to an event group (like 'MouseEvents')
e2g = exports.eventTypeToGroup = {}
for group, events of groups
    for type in events
        e2g[type] = group

ctors =
    'initEvent'         : groups['HTMLEvents']
    'initMouseEvent'    : groups['MouseEvents']
    'initKeyboardEvent' : groups['KeyboardEvent']
    'initUIEvent'       : groups['UIEvents']

# Maps an event type (like 'click') to a constructor (like 'initMouseEvent')
e2c = exports.eventTypeToConstructor = {}
for ctor, events of ctors
    for type in events
        e2c[type] = ctor

