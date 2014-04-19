class User
    __r_include : '_email'
    constructor : (@_email) ->

    getEmail : () -> return @_email

module.exports = User
