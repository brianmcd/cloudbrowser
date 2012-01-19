(function () {
  var fname = document.getElementById('fname'),
      lname = document.getElementById('lname'),
      output = document.getElementById('output');

  function onChange () {
    var first = fname.value,
        last  = lname.value;
    output.innerHTML = first + ' ' + last;
  }

  fname.addEventListener('change', onChange);
  lname.addEventListener('change', onChange);
})();
