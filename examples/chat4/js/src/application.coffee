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

app.controller "ChatCtrl", ($scope, $timeout) ->
    {currentBrowser} = cloudbrowser
    browserId = currentBrowser.getID()
    chatManager = cloudbrowser.currentAppInstanceConfig.getObj()
    $scope.userName = "Goose_#{browserId}"
    $scope.editingUserName = true
    $scope.alertMessages = []

    chatManager.users[browserId] = $scope.userName
    $scope.chatManager = chatManager

    $scope.alert = (msg)->
        console.log "whoops"
        alert = {
            msg : msg
        }
        $scope.alertMessages.push(alert)
        $timeout(()->
            $scope.removeAlert(alert)
        , 3000
        )

    $scope.removeAlert = (alert)->
        index = $scope.alertMessages.indexOf(alert)
        if index >= 0
            $scope.alertMessages.splice(index, 1)


    addMessage = (msg, type)->
        msgObj = {
            browserId : browserId
            msg : msg
            userName : $scope.userName
            time : (new Date().getTime())
        }
        msgObj.type = type if type?
        chatManager.messages.push(msgObj)
        if chatManager.messages.length > 1000
            chatManager.messages = chatManager.messages.slice(500)
        

    $scope.changeName = ()->
        if not $scope.draftUserName or $scope.draftUserName is ''
            return $scope.alert("The user name must not be empty.")
        name = $scope.draftUserName.trim()
        if name is ''
            return $scope.alert("The user name must not be empty.")
        for k, v of chatManager.users
            if k isnt browserId and v.toLowerCase() is name.toLowerCase()
                return $scope.alert("Duplicate user name.")
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
        
