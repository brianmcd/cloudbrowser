{EventEmitter} = require('events')

class User extends EventEmitter
    constructor : () ->
        @name = null
        @namespace = null
        @joinedRooms = []
        @joinedRoomsByName = {}

    setUserDetails : (user) ->
        @name = user.email
        @namespace = user.ns

    joinRoom :  (room)  ->
        name = room.name
        if @joinedRoomsByName[name]
            #@activateRoom(room)
            return
        @joinedRooms.push(room)
        @joinedRoomsByName[name] = room
        @emit('JoinedRoom', room)

    leaveRoom : (room) ->
        name = room.name
        if @joinedRoomsByName[name]?
            delete @joinedRoomsByName[name]
            @joinedRooms = @joinedRooms.filter (element, index) ->
                return element.name isnt name
            @emit('LeftRoom', name)

    getAllRooms : () ->
        return @joinedRooms

module.exports = User
