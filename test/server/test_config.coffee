
config = require '../../src/server/config'

Config = config.Config

exports.testNewConfig = (test) ->
    process.argv = ['coffee',__filename,'--compressJS','true']
    config = new Config((err,data)->
        test.ifError(err)
        test.ok(data)
        test.equal(data.cmdOptions.compressJS,true,'compressJS should be true')
        test.equal(data.serverConfig.compressJS,true,'compressJS should be true')
        test.done()
    )
#should automate user input
testLoadExistingUser = (test) ->
    mockDB ={
        findAdminUser : (key, callback) ->
            callback null, key
    }
    config = new Config((err,data)->
        data.setDatabase(mockDB)
        data.loadUserConfig((err,data) ->
            test.ifError(err)
            test.done()

            )
        )

exports.testLoadNewUser = (test) ->
    mockDB ={
        findAdminUser : (key, callback) ->
            callback null, null
        addAdminUser : (user, callback) ->
            console.log "add user #{user}"
            callback null
    }
    config = new Config((err,data)->
        data.setDatabase(mockDB)
        data.loadUserConfig((err,data) ->
            test.ifError(err)
            test.done()

            )
        )