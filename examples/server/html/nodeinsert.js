window.addEventListener('load', function () {
    var count = 0;
    setInterval(function () {
        ++count;
        var target = document.getElementById('target');
        var node = document.createTextNode('Node #' + count + ' ');
        target.appendChild(node);
    }, 1000);
});

console.log("readyState: " + window.document.readyState);
