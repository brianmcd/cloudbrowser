var repl = require('repl'),
    BI   = require('./lib/browser_instance');

var b = new BI();
var htmlpage = "<html><head><title>Title</title></head><body>This is the body</body></html>";

var repl = repl.start()
repl.context.b = b;
repl.context.htmlpage = htmlpage;
