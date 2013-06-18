Chat3 = angular.module("Chat3", [])
Util = require('util')

Chat3.controller "ChatCtrl", ($scope) ->
    $scope.joinedRooms = []
    $scope.otherRooms  = []
    currentVB          = cloudbrowser.getCurrentVirtualBrowser()
    $scope.username    = currentVB.getCreator().getEmail()
    $scope.activeRoom  = null
    $scope.roomName    = null
    $scope.currentMessage = ""
    $scope.selectedRoom   = null
    $scope.showCreateForm = false
    $scope.showJoinForm = false
    lastActiveRoom     = null

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn then fn()
        else
            this.$apply(fn)

    findRoom = (name, roomList) ->
        room = $.grep roomList, (element, index) ->
            return element.name is name
        if room.length
            return room[0]
        else return null

    addRoom = (room, roomList, setupListeners) ->
        if not findRoom(room.name, roomList)
            $scope.safeApply -> roomList.push(room)
            if setupListeners
                room.on "NewMessage", (message) ->
                    $scope.safeApply -> room.messages

    getLastActiveRoom = () ->
        if lastActiveRoom then return lastActiveRoom
        else if $scope.joinedRooms.length
            return $scope.joinedRooms[$scope.joinedRooms.length - 1]
        else return null

    chatManager = cloudbrowser.app.shared.chats

    chatManager.on "NewRoom", (room) ->
        setTimeout () ->
            if not findRoom(room.name, $scope.joinedRooms)
                $scope.safeApply -> addRoom(room, $scope.otherRooms, false)
        , 100

    for room in chatManager.getAllRooms()
        if not findRoom(room.name, $scope.joinedRooms)
            addRoom(room, $scope.otherRooms, false)

    chatUser = cloudbrowser.app.local.user
    chatUser.setUserDetails(currentVB.getCreator().toJson())

    chatUser.on "JoinedRoom", (room) ->
        addRoom(room, $scope.joinedRooms, true)
        $scope.safeApply ->
            $scope.otherRooms = $.grep $scope.otherRooms, (element, index) ->
                return element.name isnt room.name
        $scope.activate(room)

    chatUser.on "LeftRoom", (name) ->
        $scope.safeApply ->
            $scope.joinedRooms = $.grep $scope.joinedRooms, (element, index) ->
                return element.name isnt name
        addRoom(chatManager.getRoom(name), $scope.otherRooms, false)
        lastActiveRoom = null
        $scope.safeApply -> $scope.activeRoom = getLastActiveRoom()

    for room in chatUser.getAllRooms()
        addRoom(room, $scope.joinedRooms, true)
        $scope.activate(room)

    $scope.joinRoom = () ->
        chatManager.getRoom($scope.selectedRoom.name).join(chatUser)
        $scope.selectedRoom = null
        $scope.toggleForm('join')

    $scope.leaveRoom = (room) ->
        room.leave(chatUser)

    $scope.createRoom = () ->
        room = chatManager.createRoom($scope.roomName)
        room.join(chatUser)
        $scope.roomName = null
        $scope.activate(room)
        $scope.toggleForm('create')

    $scope.postMessage = () ->
        if $scope.activeRoom
            $scope.activeRoom.postMessage($scope.username, $scope.currentMessage)
            $scope.currentMessage = ""

    $scope.toggleForm = (type) ->
        if type is "create"
            $scope.showCreateForm = !$scope.showCreateForm
        else if type is "join"
            $scope.showJoinForm = !$scope.showJoinForm

    $scope.activate = (room) ->
        lastActiveRoom = $scope.activeRoom
        $scope.activeRoom = room

Chat3.directive 'enterSubmit', () ->
    directive =
        restrict: 'A',
        link: (scope, element, attrs) ->
            submit = false
            $(element).on(
                keydown: (e) ->
                    submit = false
                    if e.which is 13 and not e.shiftKey
                        submit = true
                        e.preventDefault()
                keyup: () ->
                    if submit
                        scope.$eval(attrs.enterSubmit)
                        scope.$digest()
            )
    return directive
