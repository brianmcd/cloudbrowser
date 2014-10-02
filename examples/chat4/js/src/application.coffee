app = angular.module("Chat4", [])

app.directive 'enterSubmit', () ->
    return directive =
        restrict: 'A',
        link: (scope, element, attrs) ->
            element.bind('keydown', (e) ->
                if e.which is 13
                    scope.$apply(()->
                        scope.$eval(attrs.enterSubmit)
                        )
                    e.preventDefault()
            )

app.controller "ChatCtrl", ($scope, $timeout, $rootScope) ->
    {currentBrowser} = cloudbrowser
    browserId = currentBrowser.getID()
    chatManager = cloudbrowser.currentAppInstanceConfig.getObj()
    messageId = 0
    $scope.userName = "Goose_#{browserId}"
    $scope.editingUserName = false
    $scope.alertMessages = []

    chatManager.users[browserId] = $scope.userName
    $scope.chatManager = chatManager

    newMessageHandler = (fromBrowser, version)->
        # only update the view for the newest event
        if version < chatManager.getVersion()
            return

        if fromBrowser is browserId
            return
        if $rootScope.$$phase is '$apply' or $rootScope.$$phase is '$digest'
            return
        $rootScope.$apply(angular.noop)

    eventbus = cloudbrowser.currentAppInstanceConfig.getEventBus()
    eventbus.on('newMessage', (fromBrowser, version)->
        # trigger handler asynchronsly
        setTimeout(()->
            newMessageHandler(fromBrowser, version)
        , 0)
    )

    scrollDown=()->
        messageBox = document.getElementById("chatMessageBox")
        messageBox.scrollTop = messageBox.scrollHeight

    $scope.alert = (msg)->
        alert = { msg : msg }
        $scope.alertMessages.push(alert)
        $timeout(()->
            $scope.removeAlert(alert)
        , 3000)

    $scope.removeAlert = (alert)->
        index = $scope.alertMessages.indexOf(alert)
        if index >= 0
            $scope.alertMessages.splice(index, 1)


    addMessage = (msg, type)->
        # set hash key, or Error: ngRepeat:dupes
        # Duplicate Key in Repeater.
        msgObj = {
            browserId : browserId
            msg : msg
            userName : $scope.userName
            time : Date.now()
            $$hashKey : "#{browserId}_#{messageId++}"
        }
        msgObj.type = type if type?
        chatManager.addMessage(msgObj)

        version = chatManager.getVersion()
        # scroll down to the last message. It does not work
        # setTimeout(scrollDown, 0)

        eventbus.emit('newMessage', browserId, version)


    $scope.changeName = ()->
        if not $scope.draftUserName or $scope.draftUserName is ''
            return $scope.alert("The user name must not be empty.")
        name = $scope.draftUserName.trim()
        if name is ''
            return $scope.alert("The user name must not be empty.")
        if name is $scope.userName
            $scope.editingUserName = false
            return
        for k, v of chatManager.users
            if k isnt browserId and v.toLowerCase() is name.toLowerCase()
                return $scope.alert("There is already a user called #{name}")
        addMessage("#{$scope.userName} is now #{name}", "sys")
        $scope.userName = name
        chatManager.users[browserId] = $scope.userName
        $scope.editingUserName = false

    $scope.postMessage = ()->
        addMessage($scope.currentMessage)
        $scope.currentMessage = ''

    $scope.getMsgClass = (msg)->
        if msg.type is 'sys'
            return "alert alert-success"
        return ""

