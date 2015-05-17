strategyStrs = ['multiInstance', 'singleBrowserPerUser', 'singleInstancePerUser',
'singleAppInstance']

strategyConfigs = {}

configStrategy = (name, needsLandingPage = false, needsAuth = false)->
    console.log("configStrategy #{name}")
    if strategyStrs.indexOf(name) < 0
        throw new Error("invalid strategy #{name}")
    if strategyConfigs[name]?
        throw new Error("strategy #{name} already configured")
    
    strategyConfigs[name] = {
        needsLandingPage : needsLandingPage
        needsAuth : needsAuth
    }

configStrategy('multiInstance', true, true)
configStrategy('singleBrowserPerUser', true, true)
configStrategy('singleInstancePerUser', false, true)
configStrategy('singleAppInstance')


Strategies = {
    needsLandingPage : (strategy)->
        Strategies.checkValid(strategy)
        return strategyConfigs[strategy].needsLandingPage
    isValid : (strategy)->
        return strategyStrs.indexOf(strategy) >=0
    checkValid : (strategy)->
        if strategyStrs.indexOf(strategy) < 0
            throw new Error("invalid strategy #{strategy}")
    needsAuth : (strategy)->
        Strategies.checkValid(strategy)
        return strategyConfigs[strategy].needsAuth

}

for strategyStr in strategyStrs
    if strategyConfigs[strategyStr] == null
        throw new Error("Unconfigured strategy #{strategyStr}")
    Strategies[strategyStr] = strategyStr


module.exports = Strategies