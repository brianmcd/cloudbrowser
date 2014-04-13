Master = require './master_main'

new Master((err)->
    require('../server/newbin')
    )
