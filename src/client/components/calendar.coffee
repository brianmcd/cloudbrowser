YUIComponent = require('./yui')

class Calendar extends YUIComponent
    constructor : (@socket, @node, opts) ->
        super(@socket, @node)
        @calendar = null
        @injectYUI () =>
            YUI().use 'calendar', (Y) =>
                @calendar = new Y.Calendar(opts)
                for event in ['dateClick', 'selectionChange']
                    @calendar.on event, @forwardEvent
                @calendar.render(@node)

    _getAttributes : () ->
        date          : @calendar.get('date')
        selectedDates : @calendar.get('selectedDates')

module.exports = Calendar
