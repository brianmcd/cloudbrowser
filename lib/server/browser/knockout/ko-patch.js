if (ko) {
    // This monkey patches an issue when using knockout in node and in the
    // browser.  Observables created in node won't have the SAME object as ones
    // created in the browser, so the original test fails with valid
    // observables.
    ko.isObservable = function (instance) {
        if ((instance === null) || (instance === undefined) || (instance.__ko_proto__ === undefined)) return false;
        if (instance.__ko_proto__ === ko.observable ||
            instance.__ko_proto__ === vt.ko.observable) {
            return true;
        }
        return ko.isObservable(instance.__ko_proto__); // Walk the prototype chain
    };

    // The dependencyDetection object needs to be the same among all ko
    // instances, or dependency tracking doesn't work.  Observables call
    // ko.dependencyDetection.registerDependency() when they are read, so
    // they must all call the same one.
    ko.dependencyDetection = vt.ko.dependencyDetection;
}
