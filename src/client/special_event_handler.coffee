EventTypeToGroup = require('./shared/event_lists').eventTypeToGroup
Config           = require('./shared/config')

class SpecialEventHandler
    constructor : (monitor) ->
        @monitor = monitor
        @socket = monitor.socket
        @_pendingKeyup = false
        @_queuedKeyEvents = []

    click : (remoteEvent, clientEvent, id) ->
        clientEvent.preventDefault()
        @socket.emit('processEvent',
                     remoteEvent,
                     @monitor.client.getSpecificValues(),
                     id)

    # Valid targets:
    #   input, select, textarea
    #
    change : (remoteEvent, clientEvent, id) ->
        target = clientEvent.target
        if target.clientSpecific
            return
        # TODO: use batch mechanism once it exists...this is inefficient.
        if target.tagName.toLowerCase() == 'select'
            if target.multiple == true
                for option in target.options
                    @socket.emit('setAttribute',
                                 option.__nodeID,
                                 'selected',
                                 option.selected)
            else
                @socket.emit('setAttribute',
                             clientEvent.target.__nodeID,
                             'selectedIndex',
                             clientEvent.target.selectedIndex)
        else # input or textarea
            @socket.emit('setAttribute',
                         clientEvent.target.__nodeID,
                         'value',
                         clientEvent.target.value)

    keyup : (rEvent, event, id) =>
        {target} = event
        #console.log("Keyup, setting value to : #{target.value}")
        @socket.emit('setAttribute',
                     target.__nodeID,
                     'value',
                     target.value)
        if @monitor.activeEvents[event.target.__nodeID]?['keyup']
            #console.log("Sending special event: #{rEvent.type} - #{id}")
            @socket.emit('processEvent',
                         rEvent,
                         @monitor.client.getSpecificValues(),
                         id)
        else if Config.monitorLatency
            @monitor.client.latencyMonitor.cancel(id)

module.exports = SpecialEventHandler
