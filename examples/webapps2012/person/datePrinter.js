(function () {
  var exec = require('child_process').exec;
  var thetime = document.getElementById('thetime');

  setInterval(function () {
    exec('date', function (err, stdout) {
      if (!err) {
        thetime.innerHTML = stdout;
      }
    });
  }, 1000);
})();
