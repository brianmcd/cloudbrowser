Crypto                  = require("crypto")

defaults =
    iterations : 10000
    randomPasswordStartLen : 6 #final password length after base64 encoding will be 8
    saltLength : 64

window.HashPassword = (config={}, callback) ->
    for own k, v of defaults
        config[k] = if config.hasOwnProperty k then config[k] else v

    if not config.password?
        Crypto.randomBytes config.randomPasswordStartLen, (err, buf) ->
            if err then throw err
            config.password = buf.toString 'base64'
            HashPassword config, callback

    else if not config.salt?
        Crypto.randomBytes config.saltLength, (err, buf) ->
            if err then throw err
            config.salt = new Buffer buf
            HashPassword config, callback

    else Crypto.pbkdf2 config.password, config.salt, config.iterations, config.saltLength, (err, key) ->
        if err then throw err
        config.key = key
        callback config
