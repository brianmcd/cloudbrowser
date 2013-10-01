module.exports = (grunt) ->
    grunt.loadNpmTasks('grunt-mocha-test')
    grunt.initConfig
        mochaTest :
            location :
                options :
                    reporter : 'spec'
                    require: 'coffee-script-mapped'
                src : ['test/server/bdd_location.coffee']
    grunt.registerTask('default', 'mochaTest')

