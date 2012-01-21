
// controller.js
var fname = document.getElementById('fname'),
    lname = document.getElementById('lname'),
    output = document.getElementById('output');

function onChange () {
  output.innerHTML = fname.value + ' ' 
                   + lname.value;
}

fname.addEventListener('change', onChange);
lname.addEventListener('change', onChange);

