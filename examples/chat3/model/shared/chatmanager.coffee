ChatRoom = require('./chatroom')
{EventEmitter} = require('events')

class ChatManager extends EventEmitter
    constructor : () ->
        @rooms = []
        @roomsByName = []

    createRoom : (name) ->
        if @roomsByName[name]
            throw new Error("Room already exists")
        
        room = new ChatRoom(name)
        @roomsByName[name] = room
        @rooms.push(room)
        @emit("NewRoom", room)
        return room

    getRoom :  (name) ->
        return @roomsByName[name]
    
    getAllRooms : () ->
        return @rooms

module.exports = ChatManager
