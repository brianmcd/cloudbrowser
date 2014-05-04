app = angular.module("Chat3", [])

app.controller "ChatCtrl", ($scope) ->
    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn then fn()
        else
            this.$apply(fn)

    # Properties on scope
    $scope.roomName       = null
    $scope.selectedRoom   = null
    $scope.showCreateForm = false
    $scope.showJoinForm   = false
    $scope.currentMessage = ""

    # handling new message
    newMessageHandler = (obj) ->
        if obj.browserId is browserId
            return
        $scope.safeApply ->
 
    # Initialize
    {currentBrowser} = cloudbrowser
    browserId = currentBrowser.getID()
    chatManager = cloudbrowser.currentAppInstanceConfig.getObj()
    $scope.user = chatManager.addUser(currentBrowser.getCreator(), newMessageHandler)

    # Methods on scope
    $scope.toggleForm = (type) ->
        formName = "show#{type}Form"
        $scope[formName] = not $scope[formName]

    $scope.openForm = (type) ->
        formName = "show#{type}Form"
        $scope[formName] = true

    $scope.closeForm = (type) ->
        formName = "show#{type}Form"
        $scope[formName] = false

    $scope.createRoom = () ->
        [err, room] = chatManager.createRoom($scope.roomName)
        if err
            $scope.error = err.message
        else 
            chatManager.addUserToRoom($scope.user, room)
            chatManager.emit("newRoom", {
                room:room
                user:$scope.user
                browserId : browserId
                })
        $scope.roomName = null
        $scope.closeForm('Create')


    $scope.joinRoom = () ->
        chatManager.addUserToRoom($scope.user, $scope.selectedRoom)
        $scope.selectedRoom = null
        $scope.closeForm('Join')

    $scope.leaveRoom = (room) ->
        chatManager.removeUserFromRoom($scope.user, room)

    $scope.postMessage = () ->
        if $scope.user.currentRoom
            msg = $scope.currentMessage
            $scope.user.currentRoom.postMessage($scope.user, msg)
            $scope.currentMessage = ""
            $scope.user.currentRoom.emit('newMessage',{
                user : $scope.user
                msg : msg
                browserId : browserId
                })

    # Event listeners
    chatManager.on "newRoom", (obj) ->
        if obj.browserId is browserId
            return

        $scope.safeApply ->
            if obj.user isnt $scope.user
                $scope.user.addToOtherRooms(obj.room)
            
        

app.directive 'enterSubmit', () ->
    return directive =
        restrict: 'A',
        link: (scope, element, attrs) ->
            element.bind('keydown', (e) ->                
                if e.which is 13
                    scope.safeApply -> scope.$eval(attrs.enterSubmit)
                    # clean the text area
                    element.val('')
                    element.text('')
                    e.preventDefault()
            )
