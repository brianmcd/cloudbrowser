FS    = require('fs')
Path  = require('path')
Model = require('../../lib/api/model')

exports['test'] =
    basic : (test) ->
        userModel = new Model({
            username : String
            password : String
        }, {
            folder : Path.resolve(__dirname, '..', 'fixtures', 'db')
            filename : 'username'
        })
        x = new userModel()
        test.ok(x.username instanceof String)
        test.ok(x.password instanceof String)
        test.done()

    persist : (test) ->
        folder : Path.resolve(__dirname, '..', 'fixtures', 'db')
        userModel = new Model({
            username : String
            password : String
        }, {
            folder : folder
            filename : 'username'
        })

        x = new userModel()
        x.username = 'brian'
        x.password = 'secret'
        x.persist () ->
            file = FS.readFileSync(Path.resolve(folder, 'brian'), 'utf8')
            obj = JSON.parse(file)
            test.equal(obj.username, 'brian')
            test.equal(obj.password, 'secret')
            test.done()

    load : (test) ->
        folder : Path.resolve(__dirname, '..', 'fixtures', 'db')
        userModel = new Model({
            username : String
            password : String
        }, {
            folder : folder
            filename : 'username'
        })

        x = new userModel()
        x.username = 'brian2'
        x.password = 'secret'
        x.persist () ->
            obj = userModel.load()
            test.equal(obj['brian2'].username, 'brian2')
            test.equal(obj['brian2'].password, 'secret')
            test.done()

