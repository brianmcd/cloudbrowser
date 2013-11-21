Crypto = require('crypto')
cloudbrowserError = require('../shared/cloudbrowser_error')

# Removes trailing strings "authenticate", "landing_page" and "password_reset"
# from mountPoint
exports.getParentMountPoint = (originalMountPoint) ->
    return originalMountPoint.replace(/\/(landing_page|password_reset|authenticate)$/, "")

# Hashes the password using pbkdf2
exports.hashPassword = hashPassword = (config={}, callback) ->
    defaults =
        iterations : 10000
        randomPasswordStartLen : 6 #final password length after base64 encoding will be 8
        saltLength : 64

    for own k, v of defaults
        config[k] = if config.hasOwnProperty(k) then config[k] else v

    if not config.password
        Crypto.randomBytes config.randomPasswordStartLen, (err, buf) =>
            if err then callback(err)
            else
                config.password = buf.toString('base64')
                hashPassword(config, callback)

    else if not config.salt
        Crypto.randomBytes config.saltLength, (err, buf) =>
            if err then callback(err)
            else
                config.salt = new Buffer(buf)
                hashPassword(config, callback)

    else
        Crypto.pbkdf2 config.password, config.salt,
        config.iterations, config.saltLength, (err, key) ->
            if err then callback(err)
            else
                config.key = key
                callback(null, config)

exports.areArgsValid = (argList) ->
    for arg in argList
        if typeof(arg.item) isnt arg.type
            if arg.type is "function" or not arg.action
                return false
            else
                arg.action(cloudbrowserError("PARAM_INVALID"), "- #{arg.name}")
                return false
    return true
