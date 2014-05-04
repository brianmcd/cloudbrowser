class User
    __r_include : '_email'
    constructor : (@_email) ->

    getEmail : () -> return @_email


User.getEmail = (user) ->
    if user.getEmail?
        return user.getEmail()
    if user._email?
        return user._email
    return user

User.toUser = (user)->
    if not user?
        return null
    if user.user?
        user = user.user
        
    if user.getEmail?
        return user
    if user._email?
        return new User(user._email)
    return new User(user)
    

module.exports = User


    
