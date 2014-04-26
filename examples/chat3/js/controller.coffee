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

    # Helper Functions
    newMessageHandler = () ->
        $scope.$apply()
 
    # Initialize
    {currentBrowser} = cloudbrowser
    chatManager = currentBrowser.currentAppInstanceConfig.getObj()
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
        if err then $scope.error = err.message
        else chatManager.addUserToRoom($scope.user, room)
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
            $scope.user.currentRoom.postMessage($scope.user, $scope.currentMessage)
            $scope.currentMessage = ""

    # Event listeners
    chatManager.on "newRoom", (room) ->
        $scope.safeApply -> $scope.user.addToOtherRooms(room)

app.directive 'enterSubmit', () ->
    return directive =
        restrict: 'A',
        link: (scope, element, attrs) ->
            submit = false
            $(element).on
                keydown : (e) ->
                    submit = false
                    if e.which is 13 and not e.shiftKey
                        submit = true
                        e.preventDefault()
                keyup : () ->
                    if submit
                        scope.$eval(attrs.enterSubmit)
                        scope.$digest()
