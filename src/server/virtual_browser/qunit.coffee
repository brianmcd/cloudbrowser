terminal = require('terminal')
puts         = terminal.puts.bind(terminal)
lpad         = terminal.lpad.bind(terminal)
rpad         = terminal.rpad.bind(terminal)
printWrapped = terminal.printWrapped.bind(terminal)

class QUnit
    constructor : () ->
        @currentTestName = ''
        @logEachAssert = false
        @modules = {}

    formatPassFail : (passed, total) ->
        passedStr = lpad(passed, 3)
        totalStr  = rpad(total, 3)
        passFail = "#{passedStr} of #{totalStr}"
        if passed != total
            passFail = "[red]#{passFail}[/red]"
        else
            passFail = "[green]#{passFail}[/green]"
        return passFail

    # Called for each module (e.g. core)
    moduleStart : (event) ->
        {name} = event
        puts("")
        puts("Running module: [bold]#{name}[/bold]")
        puts("")
        @currentModule = name # moduleDone doesn't work right with ?filter

    moduleDone : (event) ->
        {failed, passed, total} = event
        name = @currentModule
        puts("")
        puts("Finished module: [bold]#{name}[/bold].")
        passFail = @formatPassFail(passed, total)
        puts("#{passFail} suites passed.")
        @modules[name] =
            failed : failed
            passed : passed
            total  : total

    # Called for each test suite
    testStart : (event) ->
        @currentTestName = event.name

    testDone : (event) ->
        {name, failed, passed, total} = event
        name = rpad("[#{name}]", 70)
        puts(name + @formatPassFail(passed, total))

    done : (event) ->
        {failed, passed, total, runtime} = event
        puts("")
        puts("Finished all tests: #{passed}/#{total} assertions passed.\n")
        puts("Runtime: #{runtime} ms.")

        for name, info of @modules
            puts("#{rpad(name, 20)} #{@formatPassFail(info.passed, info.total)}")

    # Called for each assertion.
    log : (event) ->
        {result, actual, expected, message} = event
        return if result && !@logEachAssert
        if result
            str = rpad("[#{@currentTestName.slice(0, 20)}] #{message.slice(0, 50)}", 71)
            str += "[[green]PASSED[/green]]"
            puts(str)
        else
            str = '\n'
            str += rpad("[#{@currentTestName}]", 71)
            str += "[[red]FAILED[/red]]"
            puts(str)
            printWrapped(message, 80, 5)
            str =  lpad("Expected: #{expected}", 40) + '\n'
            str += lpad("Actual:   #{actual}", 40) + '\n'
            puts(str)

    onerror : (err) ->
        puts("[red][bold][underline]Uncaught Exception[/underline][/bold][/red]")
        puts(err)
        puts(err.stack)

module.exports = QUnit
