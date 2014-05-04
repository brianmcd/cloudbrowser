module.exports = (grunt) ->
    grunt.loadNpmTasks('grunt-mocha-test')
    grunt.initConfig
        mochaTest :
            server :
                options :
                    reporter : 'spec'
                    require: 'coffee-script-mapped'
                src : [
                    'test/server/location.coffee'
                    'test/server/advice.coffee'
                    'test/server/browser.coffee'
                    'test/server/resource_proxy.coffee'
                    'test/server/serializer.coffee'
                ]

    grunt.registerTask('default', 'mochaTest')
