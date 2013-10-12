ChatRoom = require('./chatroom')
{EventEmitter} = require('events')

class ChatManager extends EventEmitter
    constructor : () ->
        @rooms = []
        @errorStrings =
            roomExists : "Room with this name exists"

    createRoom : (name) ->
        for room in @rooms
            if room.name is name
                return [new Error(@errorStrings.roomExists)]
        room = new ChatRoom(name)
        @rooms.push(room)
        @emit("newRoom", room)
        return [null, room]

    addUserToRoom : (user, room, newMessageHandler) ->
        user.join(room, newMessageHandler)
        room.add(user)

    removeUserFromRoom : (user, room) ->
        user.leave(room)
        room.remove(user)

    getRooms : () ->
        return @rooms

    removeRoom : (room) ->
        idx = @rooms.indexOf(room)
        if idx isnt -1
            room.close()
            @rooms.splice(room, 1)
            
module.exports = ChatManager
