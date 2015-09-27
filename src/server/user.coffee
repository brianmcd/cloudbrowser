class User
    constructor : (@_email) ->

    getEmail : () -> 
        return @_email

    toString : () ->
        return "User #{@_email}"

    # get a unique identification string for the user
    getId : ()->
        return @_email

    # export args for nodermi
    toConstructorArguments : ()->
        return @_email


User.getEmail = (user) ->
    if not user?
        return null
    if user._email?
        return user._email
    if typeof user is 'string'
        return user
    
    throw new Error("Invalid user #{typeof user}")

User.getId = (user) ->
    return User.getEmail(user)

# convert remote obj or string to real User obj
User.toUser = (user)->
    if not user?
        return null

    if user.user?
        user = user.user

    if user instanceof User
        return user

    if user._email?
        return new User(user._email)
    return new User(user)
    

module.exports = User


    
