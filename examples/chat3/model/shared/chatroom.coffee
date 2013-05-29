{EventEmitter} = require('events')

class ChatRoom extends EventEmitter
    constructor : (@name) ->
        @users = []
        @messages = []

    postMessage : (username, message) ->
        formattedMessage = "[#{username}]: #{message}"
        @messages.push(formattedMessage)
        @emit('NewMessage', message)

    getMessages : () ->
        return @messages

    join : (user) ->
        @users.push(user)
        user.joinRoom(@)
        @emit('UserJoined', user)

    leave : (user) ->
        @users = @users.filter (element, index) ->
            return (element.name isnt user.name or element.namespace isnt user.namespace)
        user.leaveRoom(@)
        @emit('UserLeft', user)

module.exports = ChatRoom

