os = require('os')
fs = require('fs-extra')
zlib = require('zlib')
path = require('path')

tar = require('tar')

debug = require('debug')
async = require('async')
lodash = require('lodash')

logger = debug("cloudbrowser:master:appWriter")

class AppWriter
    constructor: (options) ->
        @workingDir = path.resolve("#{os.tmpdir()}","cb_#{process.pid}")
        {@deployDir, @appManager} = options
        fs.ensureDirSync(@workingDir)
        fs.ensureDirSync(@deployDir)
        logger("work on dir #{@workingDir}, deploy on #{@deployDir}")

    write:(buffer, callback) ->
        fileName = "#{@workingDir}/#{Date.now()}"
        tarballName = "#{fileName}.tar.gz"
        extractedName = "#{fileName}_extract"
        newName = null
        async.waterfall([
            (next)->
                logger("write buffer to #{tarballName}")
                fs.writeFile(tarballName, buffer, next)
            (next)->
                logger("unzip to #{extractedName}")
                fs.createReadStream(tarballName)
                .pipe(zlib.Gunzip())
                .pipe(tar.Extract
                    path : extractedName
                    type : 'Directory'
                )
                .on("error", next)
                .on("end", next)
            (next)=>
                @appManager.deployable(extractedName, next)
            (mountPoint, next)=>
                mountPoint = mountPoint.replace(/\//g, '')
                newName = path.resolve(@deployDir, "#{mountPoint}_#{Date.now().toString(36)}")
                logger("copy #{extractedName} to #{newName}")
                fs.move(extractedName, newName, next)
            ],(err)->
                fs.deleteSync(tarballName)
                fs.deleteSync(extractedName)
                if err?
                    logger("write app failed: #{err}")
                    fs.deleteSync(newName) if newName?
                    callback(err)
                    return
                callback(null, newName)
            )

module.exports = AppWriter

