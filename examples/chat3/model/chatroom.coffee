{EventEmitter} = require('events')

class ChatRoom extends EventEmitter
    constructor : (@name, @messages = [], @users = []) ->

    postMessage : (user, message) ->
        formattedMessage = "[#{user.getName()}]: #{message}"
        @messages.push(formattedMessage)
        @emit('newMessage', message)

    getName : () ->
        return @name

    add : (user) ->
        @users.push(user)

    remove : (user) ->
        idx = @users.indexOf(user)
        if idx isnt -1 then @users.splice(idx, 1)

    getMessages : () ->
        return @messages

    getUsers : () ->
        return @users

    close : () ->
        @removeAllListeners()

    getSerializableInfo : () ->
        return {
            name     : @getName()
            messages : @getMessages()
        }

module.exports = ChatRoom

