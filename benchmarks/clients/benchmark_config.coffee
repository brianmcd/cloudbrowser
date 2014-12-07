fs = require('fs')

lodash = require('lodash')
debug = require('debug')

utils = require('../../src/shared/utils')

logger = debug('cloudbrowser:benchmark:conf')

createEventByDescriptor = (options)->
    switch options.descriptor.type
        when 'eventGroup'
            return new EventGroup(options)
        when 'textInput'
            return new TextInputEventGroup(options)
        else
            return new RegularEvent(options)

ruleDefinitions = {}
textInputDefFile = "#{__dirname}/text_input_rule.json"
getTextInputDefinition = ()->
    if not ruleDefinitions[textInputDefFile]
        data = fs.readFileSync(textInputDefFile)
        ruleDefinitions[textInputDefFile] = JSON.parse(data.toString())
    return ruleDefinitions[textInputDefFile]



class TextInputEventGroup
    constructor: (options) ->
        {@descriptor, @context} = options
        @text = ''
        if @descriptor.textType is 'random'
            @text = "#{@context.clientId} want #{@context.counter}c"
            @context.counter++
        if @descriptor.textType is 'clientId'
            @text = "#{@context.clientId}"
        # to obtain charCode and which
        @upperCaseText = @text.toUpperCase()
        @textInputDefinition = getTextInputDefinition()
        @textIndex = 0
        # skip keyboard input events for characters
        @textIndex = @text.length-1 if @descriptor.keyEvent is 'basic'
        @_initializeEventQueue()

    _initializeEventQueue : ()->
        eventDescriptors = []
        @_inputKeyEvents(eventDescriptors)
        if @textIndex == @text.length-1 and @descriptor.endEvent
            endEventDescriptors = @textInputDefinition.endEvent[@descriptor.endEvent]
            if endEventDescriptors
                for eventDescriptor in endEventDescriptors
                    newEventDescriptor = lodash.clone(eventDescriptor, true)
                    if newEventDescriptor.event is 'setAttribute'
                        newEventDescriptor.args = [@descriptor.target, "value", @text]
                        newEventDescriptor.previousInputValue = @text
                    else
                        #for change event and keydown keyup of enter
                        keyEvent = newEventDescriptor.args[0]
                        keyEvent.target = @descriptor.target
                    eventDescriptors.push(newEventDescriptor)

        @eventQueue = new EventQueue({
            descriptors : eventDescriptors
            context : @context
            })

    _inputKeyEvents : (eventDescriptors)->
        return if @descriptor.keyEvent is 'basic'
        #logger("input full events")
        for eventDescriptor in @textInputDefinition.eventGroup
            newEventDescriptor = null
            if eventDescriptor.event is 'setAttribute'
                curString = @text.substring(0, @textIndex+1)
                newEventDescriptor = {
                    "event":"setAttribute",
                    "args":[@descriptor.target, "value" , curString],
                    previousInputValue : curString
                }
            else
                # deep clone the thing
                newEventDescriptor = lodash.clone(eventDescriptor, true)
                curChar = @text.charAt(@textIndex)
                
                keyEvent = newEventDescriptor.args[0]
                keyEvent.target = @descriptor.target
                keyEvent.key = curChar
                # the keycode and which are not relevant for the test,
                # keep them to make it same with a real browser
                curCharCode = @upperCaseText.charCodeAt(@textIndex)
                keyEvent.which = curCharCode
                keyEvent.keyCode = curCharCode
            eventDescriptors.push(newEventDescriptor)


    poll :()->
        if @textIndex >= @text.length
            return null
        pollOnActionQueue = @eventQueue.poll()
        if pollOnActionQueue
            return pollOnActionQueue
        else
            @textIndex++
            if @textIndex < @text.length
                @_initializeEventQueue()
            else
                @eventQueue = null
            return @poll()


class RegularEvent
    constructor: (options) ->
        {@descriptor, @context} = options
        {@type} = @descriptor
        @polled = false
        @expectIndex = 0

    poll : ()->
        if @polled
            return null
        @polled = true
        return @

    getExpectingEventName : ()->
        if @expectIndex >= @descriptor.expect.length
            return null
        return @descriptor.expect[@expectIndex].event

    # 1 means waiting, 2 means fully matched
    # we are not reject anything, if the expected event
    # does not showup, we will detect a timeout for waiting
    expect : (eventName, args)->
        if @expectIndex >= @descriptor.expect.length
            return 2
        currentExpect = @descriptor.expect[@expectIndex]
        if eventName isnt currentExpect.event
            return 1
        if currentExpect.containsText
            if not @_matchText(args, currentExpect.containsText)
                return 1
        if currentExpect.args
            if not @_matchArgs(args, currentExpect.args)
                return 1
        @expectIndex++
        if @expectIndex is @descriptor.expect.length
            return 2
        return 1

    _matchText : (args, matchRules)->
        str = JSON.stringify(args)
        for matchRule in matchRules
            pattern = ''
            if typeof matchRule is 'string'
                pattern = matchRule
            else
                pattern = @context.previousInputValue
            return false if str.indexOf(pattern) is -1
        return true

    _matchArgs : (args, expectArgs)->
        for i in [0...args.length] by 1
            if(expectArgs[i])
                if not expectArgs[i]._type
                    if not lodash.isEqual(args[i], expectArgs[i])
                        return false
                else if expectArgs[i]._type is 'clientId'
                    if args[i] isnt @context.clientId
                        return false
        return true

    emitEvent : (emitter)->
        emitArgs = [@descriptor.event]
        if @descriptor.previousInputValue?
            @context.previousInputValue = @descriptor.previousInputValue
        
        for i in @descriptor.args
            if i._type is 'clientId'
                emitArgs.push(@context.clientId)
            else
                emitArgs.push(i)
        emitter.emit.apply(emitter, emitArgs)

    getWaitDuration : ()->
        if @descriptor.wait?
            return @descriptor.wait if typeof @descriptor.wait is 'number'
            waitType = @descriptor.wait.type
            if waitType is 'random'
                max = @descriptor.wait.max
                min = if @descriptor.wait.min? then @descriptor.wait.min else 0
                return Math.random()*(max-min) + min
        return 0
        

# the difference between EventGroup and ActionQueue is that EventGroup
# iterates over the same events over and over again
class EventGroup
    constructor: (options)->
        {@descriptor, @context} = options
        @_initializeEvents()
        @currentCount = 0

    _initializeEvents : ()->
        eventDescriptors = @descriptor.events
        @actionQueue = new EventQueue({
            descriptors : eventDescriptors
            context : @context
            })

    poll: ()->
        if @currentCount >= @descriptor.count
            return null
        pollOnActionQueue = @actionQueue.poll()
        if pollOnActionQueue
           return pollOnActionQueue
        @currentCount++
        if @currentCount < @descriptor.count
             @_initializeEvents()
        else
            @actionQueue = null
        return @poll()


class EventQueue
    constructor: (options) ->
        @descriptors = lodash.clone(options.descriptors)
        {@context} = options
        @events = []
        for eventDescriptor in @descriptors
            @events.push(createEventByDescriptor({
                descriptor : eventDescriptor
                context : @context
            }))
        @currentEventIndex = 0
        @currentLoopIndex = 0

    # get the first event/head from queue
    poll : ()->
        if @currentEventIndex >= @events.length
            return null
        currentEvent = @events[@currentEventIndex]
        pollOnCurrentEvent = currentEvent.poll()
        if not pollOnCurrentEvent
            @currentEventIndex++
            return @poll()
        return pollOnCurrentEvent

class EventContext
    constructor: (options) ->
        {@clientId} = options
        @counter = 0
        @previousInputValue = null

class EventDescriptorsReader
    constructor: (options)->
        {@fileName} = options

    read : (callback)->
        fs.readFile(@fileName, (err, data)=>
            return callback(err) if err
            str = data.toString()
            descriptors = []
            descriptorStrs = str.split('===')
            for descriptorStr in descriptorStrs
                if not utils.isBlank(descriptorStr)
                    descriptorStr = descriptorStr.trim()
                    descriptors.push(JSON.parse(descriptorStr))
            callback null, descriptors
        )

exports.EventDescriptorsReader = EventDescriptorsReader
exports.EventContext = EventContext
exports.EventQueue = EventQueue