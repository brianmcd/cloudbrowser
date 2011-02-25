var manager = require('jsdom-manager');

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
