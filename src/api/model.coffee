FS   = require('fs')
Path = require('path')

module.exports = (schema, opts) ->
    {persist, folder, filename} = opts if opts?
    if !persist then persist = true
    if persist
        if !folder then throw new Error("Must supply a folder")
        if !filename then throw new Error("Must supply a filename")
    
    class Model
        # seed is a JSON.parse'd object loaded from disk.
        constructor : (seed) ->
            @_persistentProperties = []

            for key, val of schema
                persistObj = persist
                defaultValue = null
                ctor = null
                if key == 'toString'
                    this[key] = val
                    continue
                if typeof val == 'function'
                    ctor = val
                else
                    # options object style.
                    ctor = val['type']
                    if val['persist']?
                        persistObj = val['persist']
                    if val['defaultValue']?
                        defaultValue = val['defaultValue']
                if seed?[key]
                    this[key] = new ctor(seed[key])
                else if defaultValue?
                    this[key] = new ctor(defaultValue)
                else
                    this[key] = new ctor()
                if persistObj
                    @_persistentProperties.push(key)
                    if this[key].subscribe?
                        this[key].subscribe (val) =>
                            # Save to disk every time a property changes.
                            @persist()

        _toJSON : () ->
            obj = {}
            @_persistentProperties.forEach (propName) =>
                prop = this[propName]
                if prop.subscribe?
                    obj[propName] = prop()
                else
                    obj[propName] = prop
            return obj

        _dbPath : () ->
            file = this[filename]
            if typeof file == 'function'
                file = file()
            return Path.resolve(folder, file)

        # TODO: rename to "save"
        persist : (callback) ->
            json = JSON.stringify(@_toJSON())
            console.log("Persisting: #{json}")
            FS.writeFile @_dbPath(), json, (err) ->
                if err
                    console.log(err)
                    console.log(err.stack)
                    throw new Error("Couldn't persist model: " + json)
                if callback? then callback()

        destroy : (callback) ->
            FS.unlink @_dbPath(), (err) ->
                if err
                    console.log(err)
                    console.log(err.stack)
                    throw new Error("Couldn't destroy model.")
                if callback? then callback()

        @load : () ->
            obj = {}
            records = FS.readdirSync(folder)
            records.forEach (record) ->
                path = Path.resolve(folder, record)
                json = FS.readFileSync(path, 'utf8')
                info = JSON.parse(json)
                obj[record] = new Model(info)
            return obj

    return Model
