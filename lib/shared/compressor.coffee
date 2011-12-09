{EventEmitter} = require('events')

class Compressor extends EventEmitter
    constructor : () ->
        @textToSymbol = {}
        @symbolToText = {}
        @nextID = 0

    compress : (text) ->
        compressed = @textToSymbol[text]
        if !compressed
            compressed = @textToSymbol[text] = @nextID++
            @symbolToText[compressed] = text
            @emit 'newSymbol',
                original   : text
                compressed : compressed
        return compressed

    decompress : (symbol) ->
        decompressed = @symbolToText[symbol]
        if !decompressed
            throw new Error("Can't decompress: #{symbol}")

    register : (text, compressed) ->
        if @symbolToText[compressed] || @textToSymbol[text]
            throw new Error("Can't register: text=#{text} compressed=#{compressed}")
        @symbolToText[compressed] = text
        @textToSymbol[text] = compressed

module.exports = Compressor
