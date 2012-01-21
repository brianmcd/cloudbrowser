YUIComponent = require('./yui')

class Slider extends YUIComponent
    # node - the dom node that this component will be rendered into.
    # opts - sent by server, this should be the options object to
    #         pass to slider constructor.
    constructor : (@socket, @node, opts) ->
        super(@socket, @node)
        @slider = null
        @injectYUI () =>
            YUI().use 'slider', (Y) =>
                @slider = new Y.Slider(opts)
                for event in ['valueChange', 'slideStart', 'thumbMove',
                              'slideEnd', 'railMouseDown']
                    @slider.on event, @forwardEvent
                @slider.render(@node)

    setValue : (val) ->
        @slider.setValue(val)

    _getAttributes : () ->
        value : @slider.getValue()

module.exports = Slider
