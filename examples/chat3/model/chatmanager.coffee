ChatRoom = require('./chatroom')
User     = require('./user')
{EventEmitter} = require('events')

class ChatManager extends EventEmitter
    constructor : (rooms, users) ->
        @rooms = []
        @users = []
        @loadRooms(rooms) if rooms
        @loadUsers(users) if users

    loadRooms : (rooms) ->
        @createRoom(room.name, room.messages) for room in rooms

    loadUsers : (users) ->
        for user in users
            chatUser = @addUser(user.name)
            for roomName in user.otherRooms
                chatUser.addToOtherRooms(@findRoom(roomName))
            chatUser.roomsToBeJoined = user.joinedRooms
            chatUser.activateRoom(@findRoom(user.currentRoom))
    
    findUser : (userName) ->
        for user in @users
            return user if user.getName() is userName

    addUser : (userName, eventHandler) ->
        user = @findUser(userName)
        if not user
            user = new User(userName, eventHandler)
            user.addToOtherRooms(room) for room in @getRooms()
            @users.push(user)
        else
            user.setEventHandler(eventHandler)
            if user.roomsToBeJoined?
                for roomName in user.roomsToBeJoined
                    @addUserToRoom(user, @findRoom(roomName))
        return user

    findRoom : (roomName) ->
        for room in @rooms
            if room.getName() is roomName then return room

    createRoom : (name, messages) ->
        room = @findRoom(name)
        if not room
            room = new ChatRoom(name, messages)
            @rooms.push(room)
        return [null, room]

    addUserToRoom : (user, room) ->
        user.join(room)
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

    getSerializableInfo : () ->
        rooms = []
        users = []
        rooms.push(room.getSerializableInfo()) for room in @rooms
        users.push(user.getSerializableInfo()) for user in @users
        return {
            rooms : rooms
            users : users
        }
            
module.exports = ChatManager
