var vt = require('vt');

console.log('---------');
console.log('vt (' + typeof vt + '):');
for (var p in vt) {
    console.log(p);
}
console.log('---------');
console.log('BrowserManager (' + typeof vt.BrowserManager + '):');
for (var p in vt.BrowserManager) {
    console.log(p);
}
console.log('---------');
console.log('BrowserInstance (' + typeof vt.BrowserInstance + '):');
for (var p in vt.BrowserInstance) {
    console.log(p);
}
console.log('---------');


console.log(typeof vt.BrowserManager);
console.log(typeof vt.BrowserInstance);

var manager = new vt.BrowserManager();

manager.lookup(1, function (inst) {
    inst.loadPage('/hello.html', function () { 
        debugger;
        console.log(inst.clienthtml());
    });
});

/*
        var script = inst.document.createElement('script');
        script.src = 'http://code.jquery.com/jquery-1.5.min.js';

        script.onload = function () {
            console.log('HN Links');
            var $ = inst.window.$;
            $('td.title:not(:last) a').each(function() {
                console.log(' -', $(this).text());
            });
        };
        script.onerror = function () {
            console.log('Error loading jQuery');
        };
        inst.document.documentElement.appendChild(script);
*/
