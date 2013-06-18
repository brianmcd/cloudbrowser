CloudBrowser
============
CloudBrowser is a way of rethinking how we write HTML-based Rich Internet Applications, also referred to as AJAX applications.
Put simply, the key idea behind CloudBrowser is to keep the entire application, including its data model, controller logic, and view server-side,
and use the client-side browser as a (dumb) display device,
or thin client, similar to how an X Server displays a remote X client's graphical user.
CloudBrowser instances live on a server, and client browsers can connect and disconnect at will,
and it is also possible for multiple users to connect to the same instance, which yields a natural co-browsing ability.    
See [http://cloudbrowser.cs.vt.edu/](http://cloudbrowser.cs.vt.edu/) for a detailed explanation.

External Dependencies
---------------------

* Mongodb Server.

Installation and Use
--------------------
1. Install [node.js](http://nodejs.org/).
2. Clone the repository to your machine. `git clone https://github.com/brianmcd/cloudbrowser.git`
3. `cd` into the cloned CloudBrowser directory.
4. Switch to the current production branch **deployment**. `git checkout deployment`.
5. Install all the necessary npm modules. `npm install -d`
6. Install the [mongodb](http://www.mongodb.org/downloads) server on your machine. The default configuration, which binds the mongodb server to localhost, should work. 
5. Configure the server settings by creating a file server\_config.json in the CloudBrowser directory or supply the configuration parameters on the command line.
See the section on [server configuration](#server-configuration) for more details. 
6. [Optional, see below on how to try out provided examples] Create a web application using HTML/CSS/JavaScript. In the directory containing the web application, create a configuration file app\_config.json and add in
suitable configuation details. See the section on [application configuration](#web-application-configuration) for more details.
7. Run the CloudBrowser server using `./bin/server <name of the directory that contains the web application(s)>`.
This will start the server, recursively search for all applications in the given directory and mount them.
Only those applications whose source directory has an app\_config.json file will be mounted.
The mount point of the web application(s) will be displayed by the server on startup.
Multiple paths can be provided for mounting at the time of startup.
8. Visit `domain:port/<mount point of application>` in your browser.

To mount the provided examples, run `./bin/server examples`.
To view all the mounted applications visit `domain:port/`


Configuration
-------------

###Server Configuration###
These options can be set in the JSON configuration file server\_config.json or through the command line while starting the CloudBrowser server.

* **adminInterface**      - bool - Enable the admin interface. Defaults to false.
* **compression**         - bool - Enable protocol compression. Defaults to true.
* **compressJS**          - bool - Pass socket.io client and client engine through uglify and gzip. Defaults to false.
* **debug**               - bool - Enable debug mode. Defaults to false.
* **debugServer**         - bool - Enable the debug server. Defaults to false.
* **domain**              - str  - Domain name of server. Defaults to `os.hostname()`
* **homePage**            - bool - Enable mounting of the home page application at "/". Defaults to true.
* **knockout**            - bool - Enable server-side knockout.js bindings. Defaults to false.
* **monitorTraffic**      - bool - Monitor/log traffic to/from socket.io clients. Defaults to false.
* **nodeMailerEmailID**   - str  - The email ID required to send mails through the Nodemailer module. Defaults to "".
* **nodeMailerPassword**  - str  - The password required to send mails through the Nodemailer module. Defaults to "".
* **noLogs**              - bool - Disable all logging to files. Defaults to true.
* **port**                - num  - Port to use for the server. Defaults to 3000.
* **resourceProxy**       - bool - Enable the resource proxy. Defaults to true.
* **simulateLatency**     - bool | num - Simulate latency for clients in ms. Defaults to false.
* **strict**              - bool - Enable strict mode - uncaught exceptions exit the program. Defaults to false.
* **traceMem**            - bool - Trace memory usage. Defaults to false.
* **traceProtocol**       - bool - Log protocol messages to #{browserid}-rpc.log. Defaults to false.

Unless you wish to change any options, a server configuration file is not necessary.
To use Google's OpenID authentication, you'll need to set 'domain' to your machine's FQDN
or IP.
To be able to send emails (such as to send 'signup' confirmation emails to new users),
you must specify a Google account username and password in nodeMailerEmailID/nodeMailerPassword.

###Web Application Configuration###
These configuration details are specific to a web application and need to be placed in the JSON file app\_config.json inside the directory
that contains the source of the corresponding application.

* **entryPoint**                - str  - The main html file of the single page web application. **Required**
* **description**               - str  - Text describing the web application.
This will be displayed on the landing page of the application (if the instantiation strategy is set to multiInstance)
and on the home page of the server (if homePage is set to true in the server configuration).
* **authenticationInterface**   - bool - Enable the authentication interface for this application.
All users must be authenticated before being granted access to any instance of it.
* **instantiationStrategy**     - str  - Valid values are:
    1. "singleAppInstance" - One application instance for all users of the application.
    2. "singleUserInstance" - One application instance per user. authenticationInterface must be set to true for this option to make sense.
    3. "multiInstance"  - Multiple application instances per user.
authenticationInterface must be set to true and the browserLimit must be set to the number of instances available to a user.
* **browserLimit**  - num - Needed only if instantiationStrategies 2 or 3 have been set to true. Corresponds to the number of applications instances
available to the user. 

A simple configuration file need only contain the entryPoint.
