hat = require('hat')

class UuidService
    constructor: (dependencies, callback) ->
        @id = 0
        callback null, this

    getId : ()->
        @id++
        hatid = hat(16,36)
        return hatid + @id.toString(36)

module.exports = UuidService
    
