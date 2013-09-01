Async = require('async')
# nwglobal helps in using async in a new vm context
# so that the constructors of types like Array are correctly
# matched in async validity checks
# See https://github.com/Mithgol/nwglobal
NwGlobal = require('nwglobal')
currentVirtualBrowser = cloudbrowser.currentVirtualBrowser
appConfig = currentVirtualBrowser.getAppConfig()
creator = currentVirtualBrowser.getCreator()

CBLandingPage = angular.module("CBLandingPage", [])

CBLandingPage.controller "UserCtrl", ($scope, $timeout) ->
    $scope.user =
        email : creator.getEmail()
        ns    : creator.getNameSpace()
    $scope.description = appConfig.getDescription()
    $scope.mountPoint  = appConfig.getMountPoint()
    
    $scope.virtualBrowserList = []
    $scope.selected = []
    $scope.isDisabled =
        open   : true
        share  : true
        del    : true
        rename : true
    $scope.addingReaderWriter = false
    $scope.confirmDelete  = false
    $scope.addingOwner    = false
    $scope.predicate      = 'dateCreated'
    $scope.reverse        = true
    $scope.filterType     = 'all'

    $scope.safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase == '$apply' or phase == '$digest'
            if fn then fn()
        else this.$apply(fn)

    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'
             , 'Oct', 'Nov', 'Dec']

    formatDate = (date) ->
        if not date then return null
        month       = months[date.getMonth()]
        day         = date.getDate()
        year        = date.getFullYear()
        hours       = date.getHours()
        timeSuffix  = if hours < 12 then 'am' else 'pm'
        hours       = hours % 12
        hours       = if hours then hours else 12
        minutes     = date.getMinutes()
        minutes     = if minutes > 10 then minutes else '0' + minutes
        time        = hours + ":" + minutes + " " + timeSuffix
        date        = day + " " + month + " " + year + " (" + time + ")"
        return date

    # Operates on $scope.virtualBrowserList -
    # The list of browsers corresponding to the current user.
    class VirtualBrowsers
        @find : (id) ->
            return vb for vb in $scope.virtualBrowserList when vb.id is id

        @add : (vbConfig) ->
            vb = VirtualBrowsers.find(vbConfig.getID())
            if vb then return vb

            vb =
                api  : vbConfig
                id   : vbConfig.getID()
                name : vbConfig.getName()
                dateCreated  : formatDate(vbConfig.getDateCreated())

            vb.api.getOwners (err, owners) ->
                if err then return
                $scope.safeApply -> vb.owners = owners

            vb.api.getReaderWriters (err, readerWriters) ->
                if err then return
                $scope.safeApply -> vb.collaborators = readerWriters

            VirtualBrowsers.setupEventListeners(vb)
                
            $scope.virtualBrowserList.push(vb)

            return vb

        @setupEventListeners : (vb) ->
            vb.api.addEventListener 'shared', () ->
                Async.waterfall NwGlobal.Array(
                    (next) ->
                        vb.api.getOwners(next)
                    (owners, next) ->
                        $scope.safeApply -> vb.owners = owners
                        next(null)
                    (next) ->
                        vb.api.getReaderWriters(next)
                    (readersWriters, next) ->
                        $scope.safeApply -> vb.collaborators = readersWriters
                        next(null)
                ), (err) ->
                    if err then $scope.safeApply -> $scope.error = err.message

            vb.api.addEventListener 'renamed', (name) ->
                $scope.safeApply -> vb.name = name

        @remove : (id) ->
            for vb in $scope.virtualBrowserList when vb.id is id
                idx = $scope.virtualBrowserList.indexOf(vb)
                Selected.remove(id)
                return $scope.virtualBrowserList.splice(idx, 1)

    # Operates on $scope.selected - The browsers selected by the user.
    class Selected
        @add : (id) ->
            if $scope.selected.indexOf(id) is -1
                $scope.selected.push(id)

        @remove : (id) ->
            idx = $scope.selected.indexOf(id)
            if idx isnt -1 then $scope.selected.splice(idx, 1)

        @isSelected = (id) ->
            return ($scope.selected.indexOf(id) >= 0)

        @areAllSelected = () ->
            return $scope.selected.length is $scope.virtualBrowserList.length

    # Checks if user has the permission to perform the action of "type"
    # on all the selected browsers
    checkPermission = (type, callback) ->
        Async.detect $scope.selected, (vbID, callback) ->
            vb = VirtualBrowsers.find(vbID)
            vb.api.checkPermissions type, (err, hasPermission) ->
                if err then $scope.safeApply -> $scope.error = err.message
                else callback(not hasPermission)
        , (permissionDenied) -> callback(not permissionDenied)

    # Toggle the action buttons
    toggleEnabledDisabled = (numSelected) ->
        if numSelected > 0
            $scope.safeApply ->
                $scope.isDisabled.open = false
            checkPermission {remove : true}, (canRemove) ->
                $scope.safeApply ->
                    $scope.isDisabled.del = not canRemove
            checkPermission {own : true}, (isOwner) ->
                $scope.safeApply ->
                    $scope.isDisabled.share  = not isOwner
                    $scope.isDisabled.rename = not isOwner
        else
            $scope.safeApply ->
                $scope.isDisabled.open   = true
                $scope.isDisabled.del    = true
                $scope.isDisabled.rename = true
                $scope.isDisabled.share  = true

    appConfig.getVirtualBrowsers (err, virtualBrowsers) ->
        if err then return
        VirtualBrowsers.add(vbAPI) for vbAPI in virtualBrowsers

    appConfig.addEventListener 'added', (vbAPI) ->
        $scope.safeApply -> VirtualBrowsers.add(vbAPI)

    appConfig.addEventListener 'removed', (id) ->
        $scope.safeApply -> VirtualBrowsers.remove(id)

    $scope.$watch 'selected.length', (newValue, oldValue) ->
        toggleEnabledDisabled(newValue)
        $scope.addingReaderWriter = false
        $scope.addingOwner        = false

    $scope.createVB = () ->
        appConfig.createVirtualBrowser (err) ->
            if err then $scope.safeApply () -> $scope.error = err.message

    $scope.logout = () -> cloudbrowser.auth.logout()

    $scope.open = () ->
        openNewTab = (id) ->
            url = appConfig.getUrl() + "/browsers/" + id + "/index"
            win = window.open(url, '_blank')

        for id in $scope.selected
            openNewTab(id)

    $scope.remove = () ->
        for id in $scope.selected
            VirtualBrowsers.find(id).api.close (err) ->
                if err then $scope.safeApply ->
                    $scope.error = err.message
        $scope.confirmDelete = false

    $scope.areAllSelected = Selected.areAllSelected
    $scope.isSelected = Selected.isSelected
                        
    sendMail = (email, callback) ->
        subject = "CloudBrowser - #{$scope.user.email}" +
                  " shared an vb with you."
        msg = "Hi #{email}<br>To view the vb, visit" +
              " <a href='#{appConfig.getUrl()}'>#{$scope.mountPoint}</a> and" +
              " login to your existing account or use your google ID to login" +
              " if you do not have an account already."

        cloudbrowser.util.sendEmail(email, subject, msg, callback)
        
    grantPerm = (user, perm, callback) ->

        grantPermission = (id, callback) ->
            vb = VirtualBrowsers.find(id)
            Async.series NwGlobal.Array(
                (next) ->
                    vb.api.grantPermissions(perm, user, next)
                (next) ->
                    sendMail(user.getEmail(), next)
            ), callback

        Async.each($scope.selected, grantPermission, (err) ->
            callback(err, user))

    addCollaborator = (selectedUser, perm, callback) ->
        lParIdx = selectedUser.indexOf("(")
        rParIdx = selectedUser.indexOf(")")

        # If the text box entry is a selection from the typeahead
        if lParIdx isnt -1 and rParIdx isnt -1
            # Parse the string to get the email and namespace
            emailID   = selectedUser.substring(0, lParIdx-1)
            namespace = selectedUser.substring(lParIdx+1, rParIdx)
            user      = new cloudbrowser.app.User(emailID, namespace)
            appConfig.isUserRegistered user, (err, exists) ->
                if err then $scope.safeApply -> $scope.error = err.message
                else if exists
                    grantPerm(user, perm, callback)
                else $scope.safeApply -> $scope.error = "Invalid Collaborator Selected"

        # If an email address has been entered directly (not selected from the typeahead)
        # and the text entered is a valid email.
        else if lParIdx is -1 and rParIdx is -1 and
        /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test(selectedUser.toUpperCase())
            user = new cloudbrowser.app.User(selectedUser, "google")
            grantPerm(user, perm, callback)

        else $scope.error = "Invalid Collaborator Selected"

    $scope.openAddReaderWriterForm = () ->
        $scope.addingReaderWriter = !$scope.addingReaderWriter
        if $scope.addingReaderWriter then $scope.addingOwner = false

    $scope.addReaderWriter = () ->
        addCollaborator $scope.selectedReaderWriter, {readwrite:true}, (err, user) ->
            $scope.safeApply ->
                if err then $scope.error = err.message
                else
                    $scope.boxMessage = "The selected virtual browsers are now shared with " +
                    user.getEmail() + " (" + user.getNameSpace() + ")"
                    $scope.addingReaderWriter = false
                    $scope.selectedReaderWriter = null

    $scope.openAddOwnerForm = () ->
        $scope.addingOwner = !$scope.addingOwner
        if $scope.addingOwner then $scope.addingReaderWriter = false

    $scope.addOwner = () ->
        addCollaborator $scope.selectedOwner,
            own       : true
            remove    : true
            readwrite : true
        , (err, user) ->
            $scope.safeApply ->
                $scope.boxMessage = "The selected virtualBrowsers are now shared with " +
                user.getEmail() + " (" + user.getNameSpace() + ")"
                $scope.addingOwner   = false
                $scope.selectedOwner = null

    $scope.select = ($event, id) ->
        checkbox = $event.target
        if checkbox.checked then Selected.add(id) else Selected.remove(id)

    $scope.selectAll = ($event) ->
        checkbox = $event.target
        action = if checkbox.checked then 'add' else 'remove'
        Selected[action](vb.id) for vb in $scope.virtualBrowserList

    $scope.getSelectedClass = (id) ->
        if Selected.isSelected(id) then return 'highlight'
        else return ''

    $scope.rename = () ->
        VirtualBrowsers.find(id).editing = true for id in $scope.selected

    $scope.clickRename = (id) ->
        vb = VirtualBrowsers.find(id)
        vb.api.isOwner creator, (err, isOwner) ->
            if isOwner then $scope.safeApply -> vb.editing = true
        
CBLandingPage.filter "removeSlash", () ->
    return (input) ->
        mps = input.split('/')
        return mps[mps.length - 1]

# Can't use filters here
# TODO: Must convert this to a directive/service? as it involves
# asynchronous calls
CBLandingPage.filter "virtualBrowserFilter", () ->
    return (list, arg) =>
        filterType = arg.type
        user = new cloudbrowser.app.User(arg.user.email, arg.user.ns)
        modifiedList = []
        switch filterType
            when 'owned'
                (do(vb) ->
                    Async.waterfall NwGlobal.Array(
                        (next) ->
                            vb.api.isOwner(user, next)
                        (isOwner, next) ->
                            if isOwner then modifiedList.push(vb)
                    ), (err) ->
                        if err
                            $scope.safeApply -> $scope.error = err.message
                ) for vb in list
            when 'notOwned'
                (do(vb) ->
                    Async.waterfall NwGlobal.Array(
                        (next) ->
                            vb.api.isOwner(user, next)
                        (isOwner, next) ->
                            if not isOwner then modifiedList.push(vb)
                            next(null)
                    ), (err) ->
                        if err
                            $scope.safeApply -> $scope.error = err.message
                ) for vb in list
            when 'shared'
                (do(vb) ->
                    Async.waterfall NwGlobal.Array(
                        (next) ->
                            vb.api.getNumReaderWriters(next)
                        (numReaderWriters, next) ->
                            if numReaderWriters
                                modifiedList.push(vb)
                                # Bypass the waterfall
                                callback(null)
                            else
                                vb.api.getNumOwners(next)
                        (numOwners, next) ->
                            if numOwners > 1 then modifiedList.push(vb)
                            next(null)
                    ), (err) ->
                        if err
                            $scope.safeApply -> $scope.error = err.message
                ) for vb in list
            when 'notShared'
                (do(vb) ->
                    Async.waterfall NwGlobal.Array(
                        (next) ->
                            vb.api.getNumOwners(next)
                        (numOwners, next) ->
                            if numOwners is 1
                                vb.api.getNumReaderWriters(next)
                            # Bypass the waterfall
                            else callback(null)
                        (numReaderWriters, next) ->
                            if not numReaderWriters then modifiedList.push(vb)
                            next(null)
                    ), (err) ->
                        if err
                            $scope.safeApply -> $scope.error = err.message
                        else return modifiedList
                ) for vb in list
            when 'all'
                modifiedList = list
        return modifiedList

CBLandingPage.directive 'ngHasfocus', () ->
    return (scope, element, attrs) ->
        scope.$watch attrs.ngHasfocus, (nVal, oVal) ->
            if (nVal) then element[0].focus()
        element.bind 'blur', () ->
            scope.$apply(
                attrs.ngHasfocus + " = false"
                scope.vb.api.rename(scope.vb.name)
            )
        element.bind 'keydown', (e) ->
            if e.which is 13 then scope.$apply(
                attrs.ngHasfocus + " = false"
                scope.vb.api.rename(scope.vb.name)
            )

CBLandingPage.directive 'typeahead', () ->
    isUserToBeRemoved = (scope, user, permChecks, callback) ->
        Async.detect scope.selected, (vbID, callback) ->
            vb = item for item in scope.virtualBrowserList when item.id is vbID
            waterfallCallback = (err, result) ->
                if err then scope.safeApply -> scope.error = err.message
                else callback(result)
            Async.waterfall NwGlobal.Array(
                (next) ->
                    vb.api.isOwner(user, next)
                (isOwner, next) ->
                    # Bypassing the waterfall
                    if isOwner then waterfallCallback(null, true)
                    else if permChecks?.readerwriter
                        vb.api.isReaderWriter(user, next)
                    # Bypassing the waterfall
                    else waterfallCallback(null, false)
                (isReaderWriter, next) ->
                    if isReaderWriter then next(null, true)
                    else next(null, false)
            ), waterfallCallback
        , callback

    pruneList = (ngModel, users, scope, callback) ->
        switch(ngModel)
            when "selectedReaderWriter"
                index = 0
                newList = []
                Async.each users, (user, callback) ->
                    isUserToBeRemoved scope, user, {}, (toBeRemoved) ->
                        if not toBeRemoved then newList.push(user)
                        callback(null)
                , (err) -> callback(err, newList)
            when "selectedOwner"
                index = 0
                newList = []
                Async.each users, (user, callback) ->
                    isUserToBeRemoved scope, user, {readwriter:true}, (toBeRemoved) ->
                        if not toBeRemoved then newList.push(user)
                        callback(null)
                , (err) -> callback(err, newList)

    return directive =
        restrict : 'A',
        link : (scope, element, attrs) ->
            $(element).typeahead
                source : (query, process) ->
                    Async.waterfall NwGlobal.Array(
                        (next) ->
                            appConfig.getUsers(next)
                        (users, next) ->
                            pruneList(attrs.ngModel, users, scope, next)
                    ), (err, users) ->
                        if err then scope.safeApply -> scope.error = err.message
                        else
                            data = []
                            for user in users
                                data.push("#{user.getEmail()} (#{user.getNameSpace()})")
                            process(data)
                updater : (item) ->
                    scope.$apply(attrs.ngModel + " = '#{item}'")
                    return item
