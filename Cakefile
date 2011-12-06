# Note: the baseline for this was Zombie.js's Cakefile
fs            = require("fs")
path          = require("path")
{spawn, exec} = require("child_process")
stdout        = process.stdout

# Use executables installed with npm bundle.
process.env["PATH"] = "node_modules/.bin:#{process.env["PATH"]}"

# ANSI Terminal Colors.
bold  = "\033[0;1m"
red   = "\033[0;31m"
green = "\033[0;32m"
reset = "\033[0m"

# Log a message with a color.
log = (message, color, explanation) ->
  console.log color + message + reset + ' ' + (explanation or '')

# Handle error and kill the process.
onerror = (err)->
  if err
    process.stdout.write "#{red}#{err.stack}#{reset}\n"
    process.exit -1

## Setup ##
task "setup", "Install development dependencies", ->
    log "Installing required npm packages (this could take some time)...", green
    npm = spawn "npm", ["install", "--dev"]
    npm.stdout.on 'data', (data) -> process.stdout.write data + reset
    npm.on 'error', (err) -> onerror err
    npm.on 'exit', ->
        log "Pulling required git submodules into deps/", green
        git = spawn "git", ['submodule', 'update', '--init']
        git.stdout.on 'data', (data) -> process.stdout.write data + reset
        git.on 'error', (err) -> onerror err
        git.on 'exit', ->
            count = 0
            deps = fs.readdirSync('deps')
            process.chdir('deps')
            deps.forEach (dep) ->
                log "Linking #{dep}", green
                exec "ln -s ../deps/#{dep} ../node_modules/", (err, stdout) ->
                    onerror err
                    process.chdir(dep)
                    log "Installing npm packages for #{dep}", green
                    depnpm = spawn "npm", ['install']
                    depnpm.stdout.on 'data', (data) -> process.stdout.write data + reset
                    depnpm.on 'error', (err) -> onerror err
                    process.chdir('..')
                    if ++count == deps.length
                        process.chdir('..')
                        runTests()

## Building ##
build = (callback) ->
    log "Compiling CoffeeScript to JavaScript...", green
    exec "rm -rf compiled/ && coffee -c -l -b -o compiled/ lib/", (err, stdout) ->
        onerror err
        if stdout != ""
            log stdout, green
        log "Building tests...", green
        exec "rm -rf compiled-test/ && coffee -c -l -b -o compiled-test/ test/", (err, stdout) ->
            onerror err
            if stdout != ""
                log stdout, green
task "build", "Compile CoffeeScript to JavaScript", -> build()

task "watch", "Continously compile CoffeeScript to JavaScript", ->
    build ->
        cmd = spawn("coffee", ["-cwb", "-o", "compiled", "lib"])
        cmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
        cmd.on "error", onerror

        testcmd = spawn("coffee", ["-cwb", "-o", "compiled-test", "test"])
        testcmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
        testcmd.on "error", onerror

task "clean", "Remove temporary files and such", ->
    exec "rm -rf compiled/ && rm -rf compiled-test/", onerror

## Testing ##
runTests = (callback) ->
  log "Running test suite ...", green
  nodeunit = spawn("node", ["run_tests.js"])
  nodeunit.stdout.on "data", (data) -> process.stdout.write data
  nodeunit.on 'error', onerror
  nodeunit.on 'exit', () ->
      if callback
          callback()

task "test", "Run all tests", ->
  runTests()
