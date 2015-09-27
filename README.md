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

* Mongodb Server (>=2.6.0).
Download and install mongodb. Start mongodb using a data folder you choose like this:
```sh
mongod --dbpath=~/var/data/db
```


Installation
--------------------
1. Install [node.js](http://nodejs.org/).
2. Clone the repository to your machine. `git clone https://github.com/brianmcd/cloudbrowser.git`
3. `cd` into the cloned CloudBrowser directory.
4. Switch to the current production branch **deployment2**. `git checkout deployment2`.
5. Install all the necessary npm modules. `npm install -d`
6. Install the [mongodb](http://www.mongodb.org/downloads) server on your machine. The default configuration, which binds the mongodb server to localhost, should work.
5. See the section on [server configuration](#server-configuration) for more details.
6. [Optional, see below on how to try out provided examples] Create a web application using HTML/CSS/JavaScript. In the directory containing the web application, create a configuration file app\_config.json and add in
suitable configuration details. See the section on [application configuration](#web-application-configuration) for more details.

Start up
----------
CloudBrowser uses a single master multiple workers architecture.
To start a CloudBrowser cluster, you need to **start mongodb first**.

You can start the master by the following script, if you omit the configPath option, it will load config files from ProjectRoot/config.
```sh
bin/run_master.sh --configPath [config directory] [application directories...]
```

You can start a worker process by the following script, you need to specify different configPath for different workers.
```sh
bin/run_worker.sh --configPath [config directory]
```

You can also try out CloudBrowser in a single process using the single process mode:

```sh
bin/single_machine_runner.sh
```

This will start a cluster with one master and two workers in a single process.
It is equivalent to a multi-process CloudBrowser cluster started by the following commands.

```sh
bin/run_master.sh --configPath config examples src/server/applications&
bin/run_worker.sh --configPath config/worker1 &
bin/run_worker.sh --configPath config/worker2 &
```

Verify
-----------
Visit `domain:port/<mount point of application>` in your browser.


Configuration
-------------

###Server Configuration###
The folder config2 contains sample configurations for a CloudBrowser cluster of one master and two workers.

You can copy files from config2 to config folder and modify the config files based on your needs. If you are planning to deploy more than 2 worker nodes, you can run generate_worker_config.sh to generate worker configuration files.

```sh
# bin/generate_worker_config.sh [config directory] [number of workers]
bin/generate_worker_config.sh config 15
```

#### Master Configuration
Master configuration file should be named as master\_config.json. By default, the run\_master.sh script will try to look for configuration file in ProjectRoot/config directory. You could use another configuration file by setting configPath flag in command line.

```json
{
    "proxyConfig": {
        "httpPort": 3000
    },
    "databaseConfig": {
        "port": 27017
    },
    "rmiPort": 3040,
    "workerConfig": {
        "admins": [
            "admin@cloudbrowser.com"
        ],
        "defaultUser": "user@cloudbrowser.com"
        "emailerConfig":{
            "email" : "cloudbrowseradmin@gmail.com",
            "password" : "mariokart"
        }
    }
}
```


* proxyConfig : HTTP host and port for the users
    - httpPort : Port.
    - host : If you omit this field, CloudBrowser will try to figure out your domain name by querying the DNS server.

* databaseConfig : configuration for data base connection
    - host : If you are trying to deploy CloudBrowser on multiple machines, do not put localhost here
    - port
* rmiPort : the port for internal communication
* workerConfig :  service settings for worker, you can overwrite the settings in this section by specify corresponding flags in command line. Please refer [Master command line options] for available fields.
    - emailerConfig : the email account for the system to send emails, you need to configure this section to enable local user registration.
        + email : the email address to send emails. Right now only gmail account is supported.
        + password : the password of the email account

#### Worker Configuration
Worker configuration files should be named as server\_config.json.
When starting a worker by run\_worker.sh script,
you should setting configPath flag to the directory that contains the worker's configuration file.

```json
{
    "httpPort": 4000,
    "id": "worker1",
    "rmiPort": 5700,
    "masterConfig": {
        "host": "localhost",
        "rmiPort": 3040
    }
}
```

* httpPort : the port worker listens for HTTP requests, this is used internally by CloudBrowser, it is not exposed to the end user
* id : worker's id, should be unique among workers
* rmiPort : port for internal communications
* masterConfig : information of the master
    - host : the host name or IP address of the machine where the master is deployed
    - rmiPort : master's rmiPort, should be the same as the rmiPort in master\_config.json

#### Deploy on a single machine
Please allocate different httpPort and rmiPort for the master and the workers.

#### Master command line options

These options can be set in the JSON configuration file master\_config.json under the workerConfig object or through the command line while starting the CloudBrowser master server.

* **compression**         - bool - Enable protocol compression. Defaults to true.
* **compressJS**          - bool - Pass socket.io client and client engine through uglify and gzip. Defaults to false.
* **domain**              - str  - Domain name of server. Defaults to `os.hostname()`
* **noLogs**              - bool - Disable logging client-server RPC calls. Defaults to true.


###Web Application Configuration###
These configuration details are specific to a web application and need to be placed in the JSON file app\_config.json inside the directory
that contains the source of the corresponding application.

* **entryPoint**                - str  - The main HTML file of the single page web application. **Required**
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



Internals
-------------

TBC

###DB Tables Explained
To inspect the database tables we used,
you can start a mongodb shell by execute **mongo** in the mongoDB's bin directory.

####data bases

Display all the databases using 'show dbs'. You will see something like this :
```
> show dbs
UID501-cloudbrowser           0.078GB
UID501-cloudbrowser_sessions  0.078GB
admin                         (empty)
local                         0.078GB

> use UID501-cloudbrowser
switched to db UID501-cloudbrowser

> show collections
Permissions
admin_interface.users
chat3.users
counters
helloworld.users
system.indexes

> db.Permissions.find()
{ "_id" : ObjectId("53cf37f4d1dc5a9d49000001"), "_email" : "godmar@gmail.com", "apps" : { "/calendar" : { "permission" : "own" }, "/frames" : { "permission" : "own" }, "/angularjs-basic" : { "permission" : "own" }, "/chat2" : { "permission" : "own" }, "/angular-todo" : { "permission" : "own" }, "/chess" : { "permission" : "own" }, "/frames/authenticate" : { "permission" : "own" }, "/frames/password_reset" : { "permission" : "own" }, "/angularjs-basic/authenticate" : { "permission" : "own" }, "/angularjs-basic/password_reset" : { "permission" : "own" }, "/chat2/authenticate" : { "permission" : "own" }, "/chat2/password_reset" : { "permission" : "own" }, "/chat2/landing_page" : { "permission" : "own" }, "/angular-todo/authenticate" : { "permission" : "own" }, "/angular-todo/password_reset" : { "permission" : "own" }, "/chess/authenticate" : { "permission" : "own" }, "/chess/password_reset" : { "permission" : "own" } } }
```
UID***-cloudbrowser is used to store data from cloudbrowser framework and user applications.
UID***-cloudbrowser_sessions is for http sessions.

