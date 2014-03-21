hat = require('hat')

class UuidService
    constructor: (dependencies, callback) ->
        @db = dependencies.database
        @id = 0
        @db.getSequence('idprefix', 42 ,(err, obj)=>
            if err?
                return callback err, null
            
            @version=obj.seq
            #using z as seperator
            @versionStr = @version.toString(35) + 'z'
            callback null, this
            )
        
    getId : ()->
        @id++ 
        hatid = hat(16,35) + 'z'
        return hatid + @versionStr + @id.toString(35)

module.exports = UuidService
    
