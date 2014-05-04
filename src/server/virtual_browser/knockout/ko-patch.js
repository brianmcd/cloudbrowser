if (ko) {
    // This monkey patches an issue when using knockout in node and in the
    // browser.  Observables created in node won't have the SAME object as ones
    // created in the browser, so the original test fails with valid
    // observables.
    ko.isObservable = function (instance) {
        if ((instance === null) || (instance === undefined) || (instance.__ko_proto__ === undefined)) {
            return false;
        }
        if (instance.__ko_proto__ === ko.observable || instance.__ko_proto__ === cloudbrowser.ko.observable) {
            return true;
        }
        return ko.isObservable(instance.__ko_proto__); // Walk the prototype chain
    };

    ko.isWriteableObservable = function (instance) {
        var proto = instance.__ko_proto__;
        // Observable
        if (typeof instance == "function") {
            if ((proto === ko.observable) || (proto === cloudbrowser.ko.observable))
                return true;
            // Writeable dependent observable
            if (((proto === ko.dependentObservable) || (proto === cloudbrowser.ko.dependentObservable)) && instance.hasWriteFunction)
                return true;
        }
        // Anything else
        return false;
    }

    // The dependencyDetection object needs to be the same among all ko
    // instances, or dependency tracking doesn't work.  Observables call
    // ko.dependencyDetection.registerDependency() when they are read, so
    // they must all call the same one.
    ko.dependencyDetection = cloudbrowser.ko.dependencyDetection;

    // We need to clean up all of the nodes, which removes references to shared
    // data, fixing memory leaks that prevented pretty much anything from being
    // GC'd (Browser, Window, etc).
    window.addEventListener('close', function () {
        ko.cleanNode(document);
    });
}
