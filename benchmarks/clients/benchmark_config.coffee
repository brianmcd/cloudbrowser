fs = require('fs')
util = require('util')

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
            # random means generating a unique string, these strings cannot be
            # substring to each other
            @text = "#{@context.clientId} says #{@context.counter}c"
            @context.counter++
        if @descriptor.textType is 'clientId'
            @text = "#{@context.clientId}"

        @endText = @text
        if @descriptor.endEvent is 'enterKey' and @descriptor.tag is 'textarea'
            @endText = "#{@text}\n"
        
        # to obtain charCode and which
        @upperCaseText = @text.toUpperCase()
        @textInputDefinition = getTextInputDefinition()
        @textIndex = 0
        # skip keyboard input events for individual characters,
        # only the final string is sent to the server
        @textIndex = @text.length-1 if @descriptor.keyEvent is 'basic'
        @_initializeEventQueue()

    _initializeEventQueue : ()->
        eventDescriptors = []
        @_inputKeyEvents(eventDescriptors)
        if @textIndex == @text.length-1 and @descriptor.endEvent
            # user specified what could happen at the end of the input task.
            # right now only one kind of endEvent is defined, that is hitting Enter key.
            # see text_input_rule for details
            endEventDescriptors = @_getEndEventDescriptors()

            for eventDescriptor in endEventDescriptors
                newEventDescriptor = @_createTopLayerEvent(eventDescriptor, @text, @endText)
                eventDescriptors.push(newEventDescriptor)

        @eventQueue = new EventQueue({
            descriptors : eventDescriptors
            context : @context
            })

    _getEndEventDescriptors : ()->
        if not @endEventDescriptors?
            # find tag specific end event descriptor first
            result = @textInputDefinition.endEvent["#{@descriptor.endEvent}_#{@descriptor.tag}"]
            if not result?
                result = @textInputDefinition.endEvent["#{@descriptor.endEvent}"]
            if not result?
                errorMsg = "cannot find endEvent for #{JSON.stringify(@descriptor)}"
                logger(errorMsg)
                throw new Error(errorMsg)
            @endEventDescriptors = result
        return @endEventDescriptors


    # create key events for individule characters in a input task.
    # input "abc" in a text input includes keydown and keyup for "a", "b", "c"
    _inputKeyEvents : (eventDescriptors)->
        return if @descriptor.keyEvent is 'basic'
        #logger("input full events")
        for eventDescriptor in @textInputDefinition.eventGroup
            curString = @text.substring(0, @textIndex+1)
            newEventDescriptor = @_createTopLayerEvent(eventDescriptor, curString)
            eventDescriptors.push(newEventDescriptor)

    _createTopLayerEvent : (eventDescriptor, curString, nextString)->
        newEventDescriptor = null
        switch eventDescriptor.event
            when 'setAttribute'
                newEventDescriptor = {
                    "event":"setAttribute",
                    "args":[@descriptor.target, "value" , curString]
                }
                break
            when 'input'
                newEventDescriptor = lodash.clone(eventDescriptor, true)
                inputEvents = newEventDescriptor.args[0]
                for i in [0...inputEvents.length] by 1
                    inputEvent = inputEvents[i]
                    # nextString is for simulating hitting enter key on a textarea, the following events will be batched and sent
                    # by client engine
                    # {input, [{type : input, _newValue : "a"}, {type : keydown, key : "enter"}, {type : input, _newValue : "a\n"}]}
                    if i is inputEvents.length-1 and nextString?
                        @_createLayer2Event(inputEvent, nextString)
                    else
                        @_createLayer2Event(inputEvent, curString)
                break
            when 'processEvent'
                newEventDescriptor = lodash.clone(eventDescriptor, true)
                @_createLayer2Event(newEventDescriptor.args[0], curString)
                break
            else
                errorMsg = "unknown evnet #{eventDescriptor.event}"
                logger(errorMsg)
                throw new Error(errorMsg)
        # curString will be used to check server side echoed message
        newEventDescriptor.previousInputValue = curString
        return newEventDescriptor


    _createLayer2Event : (eventDescriptor, curString)->
        switch eventDescriptor.type
            when 'input'
                eventDescriptor._newValue = curString
                eventDescriptor.target = @descriptor.target
                break
            when 'keydown', 'keypress', 'keyup'
                curChar = @text.charAt(@textIndex)
                eventDescriptor.target = @descriptor.target
                # do not fill key codes if it is defined
                if not eventDescriptor.which?
                    eventDescriptor.key = curChar
                    curCharCode = @upperCaseText.charCodeAt(@textIndex)
                    eventDescriptor.which = curCharCode
                    eventDescriptor.keyCode = curCharCode
                break


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
        expectedEvent = @descriptor.expect[@expectIndex].event
        if typeof expectedEvent is 'string'
            return expectedEvent
        if util.isArray(expectedEvent)
            return expectedEvent.join(' or ')
        return null

    # 1 means waiting, 2 means fully matched
    # we are not reject anything, if the expected event
    # does not showup, we will detect a timeout for waiting
    expect : (eventName, args)->
        # logger("match #{eventName} #{JSON.stringify(args)}")
        if @expectIndex >= @descriptor.expect.length
            return 2
        currentExpect = @descriptor.expect[@expectIndex]
        if not @_matchEventName(eventName,currentExpect)
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

    _matchEventName : (eventName, expect) ->
        expectedEvent = expect.event
        return true if eventName is expectedEvent
        if util.isArray(expectedEvent)
            return expectedEvent.indexOf(eventName) >= 0
        # this would be extremely slow
        if expectedEvent.type is 'any'
            return true
        else if expectedEvent.type?
            throw new Error("unsupported expectedEvent type #{expectedEvent.type}")
        
        return false

    _matchText : (args, matchRules)->
        str = JSON.stringify(args)
        for matchRule in matchRules
            pattern = ''
            if typeof matchRule is 'string'
                pattern = matchRule
            else
                pattern = @context.previousInputValue
            # logger("match #{pattern} with #{str}")
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
            # logger("set context previousInputValue #{@context.previousInputValue}")

        for i in @descriptor.args
            if i._type is 'clientId'
                emitArgs.push(@context.clientId)
            else
                emitArgs.push(i)
        # logger("emit #{JSON.stringify(emitArgs)}")
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