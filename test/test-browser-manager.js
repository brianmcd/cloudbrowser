var vt      = require('vt'),
    Envs    = require('./fixtures/fixtures').Environments;

exports.testLookup = function (test) {
    var count = 0;
    Envs.forEach(function (env) {
        var manager = new vt.BrowserManager(env);
        var instances = [];

        var instancesCreated = 0; //TODO: gotta be a better way...
        var instancesChecked = 0;
        for (var i = 0; i < 10; i++) {
            manager.lookup(i, function (inst) {
                instances[i] = inst;
                test.equal(inst.constructor, 
                           vt.BrowserInstance,
                           "BrowserManager.lookup() should return a " + 
                           "BrowserInstance");
                if (++instancesCreated == 10) {
                    for (var p = 0; p < 10; p++) {
                        manager.lookup(p, function (inst) {
                            test.strictEqual(instances[p], 
                                             inst,
                                             "Successive lookup()s for the same id " +
                                             "should return the same BrowserInstance.");
                            if (++instancesChecked == instancesCreated) {
                                console.log('Finished with ' + env);
                                if (++count == Envs.length) {
                                    test.done();
                                }
                            }
                        });
                    }
                }
            });
        }
    });
};
