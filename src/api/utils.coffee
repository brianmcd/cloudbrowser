Crypto = require('crypto')

# Removes trailing strings "authenticate", "landing_page" and "password_reset"
# from mountPoint
exports.getParentMountPoint = (originalMountPoint) ->
    delimiters  = ["authenticate", "landing_page", "password_reset"]
    components  = originalMountPoint.split("/")
    index       = 1
    mountPoint  = ""
    while delimiters.indexOf(components[index]) is -1 and index < components.length
        mountPoint += "/" + components[index++]
    return mountPoint

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

exports.compare = (app1, app2) ->
    if(app1.getMountPoint() < app2.getMountPoint())
        return -1
    else if app1.getMountPoint() > app2.getMountPoint()
        return 1
    else return 0
