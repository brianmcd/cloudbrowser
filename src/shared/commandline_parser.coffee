nomnom = require('nomnom')


###

a wrapper around nomnom, you can define 'env' in options to 
create default value based on environment variables.
like 
timeout : {
    env : 'CB_TIMEOUT'
    default : 1000*30
    type : 'number'
    help : 'connection timeout in ms'
}
if environment variable CB_TIMEOUT is defined, default value will be 
override by that environment value.
argv is optional, by default it is process.argv
###
exports.parse=(options, argv)->
    # if we define env option, use the enviroment variable as default
    for k, v of options
        if v.env? and v.default? and process.env[v.env]? and process.env[v.env].trim().length > 0
            defaultVal = process.env[v.env].trim()
            if v.type? and v.type isnt 'string'
                try
                    defaultVal = JSON.parse(defaultVal)
                    v.default = defaultVal
                catch e
                    console.log("parse error, #{defaultVal} is not of type #{v.type}")
            else
                v.default = defaultVal
    if not argv?
        argv = process.argv
    opts = nomnom.script(argv[1]).options(options).parse(argv.slice(2))
    return opts