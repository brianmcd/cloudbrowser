debug = require('debug')
lodash = require('lodash')

logger = debug('cloudbrowser:worker:browser')


renderControlEvents = ['pauseRendering', 'resumeRendering']


bufferEmit = (args, context)->
    # cannot change the event directly, it might be shared by multiple sockets
    args = lodash.clone(args)
    eventName = args[0]
    if eventName is 'pauseRendering'
        @buffering = true
        return
    
    if not @buffering and eventName isnt 'resumeRendering'
        logger("send event without buffering")
        @doEmit(args)
        return
    # buffering
    if eventName is 'resumeRendering'
        @clientId = args[1]
        @buffering=false
        # only send message if we have real messages
        if @buffer.length > 0
            buffer = deduplicateBuffer(@buffer, this, context)
            if buffer.length > 1
                logger("buffer send #{buffer.length} events")
                @doEmit(['batch', buffer, @clientId])
            else if buffer.length == 1
                logger("buffer send #{buffer.length} events")
                @doEmit(buffer[0])
            else
                logger("skip send events after deduplication")    
            @buffer=[]
        else
            logger("skip send events")
    else
        @buffer.push(args)
    return

deduplicateBuffer = (buffer, socket, context)->
    if buffer.length<=1
        return buffer
    finalEvts = {}
    hasDuplicates = false
    for evt in buffer
        if evt[0] is 'DOMAttrModified'
            nodeId = evt[1]
            attrName = evt[2]
            if not finalEvts[nodeId]?
                finalEvts[nodeId] = {}
            
            if finalEvts[nodeId][attrName]?
                finalEvts[nodeId][attrName]['_duplicate']=true
                hasDuplicates=true
            finalEvts[nodeId][attrName] = evt
            # if the value sending to client is already there. evt[3] is the attribute value
            if context and context.from is socket and context.target is nodeId and context.value is evt[3]
                evt._duplicate = true
                hasDuplicates=true
            
    return buffer if not hasDuplicates

    newBuffer = []
    for evt in buffer
        newBuffer.push(evt) if not evt._duplicate
    return newBuffer
    
    

normalEmit = (args)->
    @socket.emit.apply(@socket, args)

compressedEmit = (args)->
    # do not change events directly, shared by multiple sockets
    args = lodash.clone(args)
    eventName = args[0]
    args[0]=@compressor.compress(eventName)
    if eventName is 'batch'
        events = args[1]
        # clone the events array
        clonedEvents = []
        for event in events
            clonedEvent = lodash.clone(event)
            clonedEvent[0] =@compressor.compress(clonedEvent[0])
            clonedEvents.push(clonedEvent)
        args[1] = clonedEvents
    @socket.emit.apply(@socket, args)



class Socket 
    constructor : (options)->
        {@socket, @compressor, @compression} = options
        socket = @socket
        self = @
        for func in ['on', 'emit', 'close', 'removeAllListeners']
            do (func, socket, self)->
                self[func] =()->
                    socket[func].apply(socket, arguments)

        for attr in ['request']
            @[attr]=socket[attr]
        
        if options.compression
            @doEmit=compressedEmit
        else
            @doEmit=normalEmit
        
        if options.buffer
            @buffer = []
            @emitCompressed=bufferEmit
        else
            @emitCompressed=@doEmit

exports.adviceSocket = (socket, options)->
    return new Socket(socket, options)
        