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
  if color
      console.log color + message + reset + ' ' + (explanation or '')
  else
      process.stdout.write(message.toString().trim() + '\n')

# Handle error and kill the process.
onerror = (err)->
  if err
    process.stdout.write("#{red}#{err.stack}#{reset}\n")
    process.exit(-1)

## Setup ##
task "setup", "Install development dependencies", () ->
    npmInstall = (callback, target) ->
        args = ['install']
        if target?
            args.push(target)
        npm = spawn('npm', args)
        npm.stdout.on('data', log)
        npm.stderr.on('data', log)
        npm.on('error', onerror)
        npm.on('exit', callback) if callback?

    updateSubmodules = (callback) ->
        log('Updating git submodules.', green)
        git = spawn('git', ['submodule', 'update', '--init'])
        git.stdout.on('data', log)
        git.stderr.on('data', log)
        git.on 'exit', () ->
            log('Done updating git submodules', green)
            callback()

    installSubmodules = (callback) ->
        log('Installing git submodules into node_modules.', green)
        count = 0
        checkIfDone = () ->
            if ++count == deps.length
                console.log('Done installing git submodules.', green)
                callback()
        deps = fs.readdirSync('deps')
        for dep in deps
            depsPath = path.resolve(__dirname, 'deps', dep)
            if path.existsSync(path.resolve(depsPath, 'package.json'))
                log("Installing npm modules for #{dep}")
                npmInstall(checkIfDone, "./deps/#{dep}")
            else
                checkIfDone()

    fs.mkdirSync('node_modules') if !path.existsSync('node_modules')
    updateSubmodules () ->
        installSubmodules () ->
            log('Installing top level node_modules from package.json.', green)
            npmInstall () ->
                log('Done installing top level node_modules.', green)
                log("You should probably run 'cake test' to make sure everything works.", green)

task 'update', "Update the project (update submodules and node_modules).", () ->
    invoke('setup')

## Build ##
build = (callback) ->
    log "Compiling CoffeeScript to JavaScript...", green
    exec "rm -rf lib/ && coffee -c -l -b -o lib/ src/", (err, stdout) ->
        onerror err
        if stdout != ""
            log stdout, green
        linkFiles(callback)
task "build", "Compile CoffeeScript to JavaScript", -> build()

## Watch ##
task "watch", "Continously compile CoffeeScript to JavaScript", ->
    build ->
        cmd = spawn("coffee", ["-cwb", "-o", "lib", "src"])
        cmd.stdout.on "data", (data)-> process.stdout.write green + data + reset
        cmd.on "error", onerror

## Clean ##
task "clean", "Remove temporary files and such", ->
    exec "rm -rf lib/", onerror

## Testing ##
runTests = (callback) ->
  log "Running test suite ...", green
  nodeunit = spawn(path.resolve(__dirname, 'run_tests.js'))
  nodeunit.stdout.on 'data', (data) ->
      process.stdout.write(data)

task "test", "Run all tests", ->
  runTests()
