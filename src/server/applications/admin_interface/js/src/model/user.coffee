class User
    constructor : (user) ->
        @emailID          = user
        @browserIDMgr     = new POJOListManager()
        @appInstanceIDMgr = new POJOListManager()

# Exporting
this.User = User
