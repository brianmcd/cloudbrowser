hat = require('hat')
debug = require('debug')
###
generate uniq id.
###
logger = debug('cloudbrowser:worker:init')

class UuidService
    constructor: (dependencies, callback) ->
        @db = dependencies.database
        @id = 0
        # version is incremented every time this constructor is called
        @db.getSequence('idprefix', 42 ,(err, obj)=>
            if err?
                return callback(err)
            @version = obj.seq
            #using z as separator
            @versionStr = @version.toString(35) + 'z'
            logger("start with version #{@versionStr}")
            callback null, this
            )
        
    getId : ()->
        # [random id]z[version]z[counter]
        @id++ 
        hatid = hat(16,35) + 'z'
        return hatid + @versionStr + @id.toString(35)

module.exports = UuidService
    
