
// datePrinter.js
var proc = require('child_process');
setInterval(function () {
  proc.exec('date "+%F %r"', function (e, out) {
    document.getElementById('thetime')
            .innerHTML = out;
  });
}, 1000);

