// From: https://github.com/driverdan/node-XMLHttpRequest
/**
 * Wrapper for built-in http.js to emulate the browser XMLHttpRequest object.
 *
 * This can be used with JS designed for browsers to improve reuse of code and
 * allow the use of existing libraries.
 *
 * Usage: include("XMLHttpRequest.js") and use XMLHttpRequest per W3C specs.
 *
 * @todo SSL Support
 * @author Dan DeFelippi <dan@driverdan.com>
 * @license MIT
 */

var Url = require("url")
	,sys = require("util");

exports.ImportXMLHttpRequest = function (window) {
    window.XMLHttpRequest = function XMLHttpRequest () {
        /**
         * Private variables
         */
        var self = this;
        var http = require('http');
        var https = require('https');

        // Holds http.js objects
        var client;
        var request;
        var response;
        
        // Request settings
        var settings = {};
        
        // Set some default headers
        var defaultHeaders = {
            "User-Agent": "node.js",
            "Accept": "*/*",
        };
        
        var headers = defaultHeaders;
        
        /**
         * Constants
         */
        this.UNSENT = 0;
        this.OPENED = 1;
        this.HEADERS_RECEIVED = 2;
        this.LOADING = 3;
        this.DONE = 4;

        /**
         * Public vars
         */
        // Current state
        this.readyState = this.UNSENT;

        // default ready state change handler in case one is not set or is set late
        this.onreadystatechange = function() {};

        // Result & response
        this.responseText = "";
        this.responseXML = "";
        this.status = null;
        this.statusText = null;
            
        /**
         * Open the connection. Currently supports local server requests.
         *
         * @param string method Connection method (eg GET, POST)
         * @param string url URL for the connection.
         * @param boolean async Asynchronous connection. Default is true.
         * @param string user Username for basic authentication (optional)
         * @param string password Password for basic authentication (optional)
         */
        this.open = function(method, url, async, user, password) {
            settings = {
                "method": method,
                "url": url,
                "async": async || null,
                "user": user || null,
                "password": password || null
            };
            
            this.abort();

            setState(this.OPENED);
        };
        
        /**
         * Sets a header for the request.
         *
         * @param string header Header name
         * @param string value Header value
         */
        this.setRequestHeader = function(header, value) {
            headers[header] = value;
        };
        
        /**
         * Gets a header from the server response.
         *
         * @param string header Name of header to get.
         * @return string Text of the header or null if it doesn't exist.
         */
        this.getResponseHeader = function(header) {
            if (this.readyState > this.OPENED && response.headers[header]) {
                return header + ": " + response.headers[header];
            }
            
            return null;
        };
        
        /**
         * Gets all the response headers.
         *
         * @return string 
         */
        this.getAllResponseHeaders = function() {
            if (this.readyState < this.HEADERS_RECEIVED) {
                throw "INVALID_STATE_ERR: Headers have not been received.";
            }
            var result = "";
            
            for (var i in response.headers) {
                result += i + ": " + response.headers[i] + "\r\n";
            }
            return result.substr(0, result.length - 2);
        };

        /**
         * Sends the request to the server.
         *
         * @param string data Optional data to send as request body.
         */
        this.send = function(data) {
            if (this.readyState != this.OPENED) {
                throw "INVALID_STATE_ERR: connection must be opened before send() is called";
            }
            
            var ssl = false;
            var url = Url.parse(settings.url);
            // Whether or not XHR.open() was called with a relative URL.
            var relative = false;
            
            var port, host, uri, parsed;
            // Determine the server
            switch (url.protocol) {
                case 'https:':
                    ssl = true;
                    // SSL & non-SSL both need host, no break here.
                case 'http:':
                    host = url.hostname;
                    port = url.port || (ssl ? 443 : 80);
                    uri = url.pathname + (url.search ? url.search : '');
                    break;
                
                case undefined:
                case '':
                    host = window.location.hostname;
                    port = window.location.port;
                    uri = url.pathname + (url.search ? url.search : '');
                    uri = Url.resolve(window.location.href, uri);
                    parsed = Url.parse(uri);
                    uri = parsed.pathname + (parsed.search || '');
                    break;
                
                default:
                    throw "Protocol not supported.";
            }
            
            // Set the Host header or the server may reject the request
            this.setRequestHeader("Host", host);

            // Set Basic Auth if necessary
            if (settings.user) {
                if (typeof settings.password == "undefined") {
                    settings.password = "";
                }
                var authBuf = new Buffer(settings.user + ":" + settings.password);
                headers["Authorization"] = "Basic " + authBuf.toString("base64");
            }
            
            // Set content length header
            if (settings.method == "GET" || settings.method == "HEAD") {
                data = null;
            } else if (data) {
                this.setRequestHeader("Content-Length", Buffer.byteLength(data));
                
                if (!headers["Content-Type"]) {
                    this.setRequestHeader("Content-Type", "text/plain;charset=UTF-8");
                }
            }

            // Use the proper protocol
            var doRequest = ssl ? https.request : http.request;

            var options = {
                host: host,
                port: port,
                path: uri,
                method: settings.method,
                headers: headers
            };

            var req = doRequest(options, function(res) {
                response = res;
                response.setEncoding("utf8");

                setState(self.HEADERS_RECEIVED);
                self.status = response.statusCode;

                response.on('data', function(chunk) {
                    // Make sure there's some data
                    if (chunk) {
                        self.responseText += chunk;
                    }
                    setState(self.LOADING);
                });

                response.on('end', function() {
                    setState(self.DONE);
                });

                response.on('error', function() {
                    self.handleError(error);
                });
            }).on('error', function(error) {
                self.handleError(error);
            });
            
            // Node 0.4 and later won't accept empty data. Make sure it's needed.
            if (data) {
                req.write(data);
            }
            
            req.end();
        };

        this.handleError = function(error) {
            this.status = 503;
            this.statusText = error;
            this.responseText = error.stack;
            setState(this.DONE);
        };

        /**
         * Aborts a request.
         */
        this.abort = function() {
            headers = defaultHeaders;
            this.readyState = this.UNSENT;
            this.responseText = "";
            this.responseXML = "";
        };
        
        /**
         * Changes readyState and calls onreadystatechange.
         *
         * @param int state New state
         */
        var setState = function(state) {
            self.readyState = state;
            self.onreadystatechange();
        }
    };
};
