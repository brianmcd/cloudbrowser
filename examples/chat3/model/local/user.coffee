{EventEmitter} = require('events')

class User
    constructor : (user) ->
        @name = user
        @joinedRooms = []
        @otherRooms  = []
        @currentRoom = null

    getName : () ->
        return @name

    activateRoom : (room) ->
        @currentRoom = room

    deactivateRoom : () ->
        @currentRoom = null

    join :  (room, newMessageHandler)  ->
        if @joinedRooms.indexOf(room) is -1
            @removeFromOtherRooms(room)
            @joinedRooms.push(room)
            room.on('newMessage', newMessageHandler)
        @activateRoom(room)

    leave : (room) ->
        idx = @joinedRooms.indexOf(room)
        if idx isnt -1 then @joinedRooms.splice(idx, 1)
        @addToOtherRooms(room)
        if @currentRoom is room
            if @joinedRooms.length then @activateRoom(@joinedRooms[0])
            else @deactivateRoom()

    removeFromOtherRooms : (room) ->
        idx = @otherRooms.indexOf(room)
        if idx isnt -1 then @otherRooms.splice(idx, 1)

    addToOtherRooms : (room) ->
        if @otherRooms.indexOf(room) is -1 then @otherRooms.push(room)

module.exports = User
