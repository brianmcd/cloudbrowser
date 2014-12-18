debug = require('debug')

logger = debug('cloudbrowser:worker:browser')


renderControlEvents = ['pauseRendering', 'resumeRendering']


bufferEmit = ()->
    eventName = arguments[0]
    if eventName is 'pauseRendering'
        @buffering = true
        return
    
    if not @buffering
        logger("send event without buffering")
        @doEmit.apply(@, arguments)
        return
    # buffering
    if eventName is 'resumeRendering'
        @clientId = arguments[1]
        @buffering=false
        # only send message if we have real messages
        if @buffer.length > 0
            logger("buffer send #{@buffer.length} events")
            if @buffer.length > 1
                @doEmit('batch', @buffer, @clientId)
            else
                @doEmit.apply(@, @buffer[0])
            @buffer=[]
        else
            logger("skip send events")
    else
        @buffer.push(arguments)
    return

normalEmit = ()->
    @socket.emit.apply(@socket, arguments)

compressedEmit = ()->
    eventName = arguments[0]
    arguments[0]=@compressor.compress(eventName)
    if eventName is 'batch'
        events = arguments[1]
        for eventArgs in events
            eventArgs[0] =@compressor.compress(eventArgs[0])
    @socket.emit.apply(@socket, arguments)


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
        