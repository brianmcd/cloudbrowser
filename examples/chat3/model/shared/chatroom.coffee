{EventEmitter} = require('events')

class ChatRoom extends EventEmitter
    constructor : (@name) ->
        @users = []
        @messages = []

    postMessage : (user, message) ->
        formattedMessage = "[#{user.getName()}]: #{message}"
        @messages.push(formattedMessage)
        @emit('newMessage', message)

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

module.exports = ChatRoom

