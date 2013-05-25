# Buildbot Sample Configuration

This document describes how to do continuous integration of webapps with Buildbot. It contains configuration files for Buildbot, Git and Apache.

## 1. Scenario

1. One public Django pluggable application.
2. One private Django project that uses the previous application.
3. Buildbot has to run tests for both, the app and the project.
4. Buildbot will build the app when changes hit app's repository.
5. Buildbot will build the project when changes hit project's repository and right after building the app.
6. Project's repository is private and hosted in an in-house server.
7. App's repository is public and hosted in GitHub.
8. App and project have to be build under supported versions of Python/Django.
9. Buildbot has to produce green or red images to highlight build results.
10. Buildbot has to show a web with build results.


## 2. Solution

1. Buildbot's master and slave will live in the same machine.
2. There will be 3 Python virtualenv to support Django v1.4/v1.5 under Python v2.7, and Django v1.5 under Python v3.2.
3. Buildbot will have 3 slaves one per virtualenv.
4. Virtualenvs will get active at OS startup time, before launching slaves.
5. Project's repository in the in-house server will get a new `post-receive` hook script that will notify Buildbot on changes.
6. Buildbot will accept HTTP POST requests from GitHub.
7. App's GitHub repository will get a new WebHook URL pointing to Buildbot's web interface.
8. Apache or Nginx will handle requests to both Buildbot web interface.


## 3. Setup

The following setup has been made in a fresh KVM virtual machine running Ubuntu Server 12.04 with the following extra packages installed:

    root@server:~# apt-get install apache2 python-pip python-virtualenv python3 git tree 

The Setup consists of the following steps:

1. Setup the in-house Git repository for the Django project
2. Setup the GitHub Git repository for the Django app
3. Install Buildbot
4. Configure Buildbot
5. Web servers setup


### 3.1 Setup the in-house Git repository for the Django project

[Django-sample-project](https://github.com/danirus/django-sample-project) it's an implementation of the official [Django tutorial](https://docs.djangoproject.com/en/1.5/intro/tutorial01/). It represents the private Django project for the sample configuration.

The following steps create the private in-house Git repository for the project. Create a git user and group, and add your username to the git group: 

    root@server:~# useradd -m -s /bin/bash git
    root@server:~# usermod -G git youruser


Clone a bare copy of [django-sample-project](https://github.com/danirus/django-sample-project) to start off the in-house repository:

    root@server:~# su - git
    git@server:~$ git clone --bare git://github.com/danirus/django-sample-project.git


Copy the ``post-receive`` file to ``/home/git/django-sample-project.git/hooks/``. The post-receive hook runs a script that will notify buildbot when changes hit the project's repository.

If your Buildbot's master lives in a different host:port add the ``--master ipaddress:port`` option to the hook along with the --repository option.


### 3.2 Setup the Github repository for the Django app

This step requires the server to be reacheable from the outside world as GitHub will post a HTTP request to Buildbot. If it's not (because you are playing around with a VM, just do the same with the app as what you've done with the project).

Fork [django-sample-app](https://github.com/danirus/django-sample-app) in your own GitHub account. Then go to the repository settings, click on Service Hooks, and WebHook URLS. Add the URL of your Buildbot master with the path to the GitHub hook:

    http://buildbot.myservice.info/change_hook/github

Buildbot's path for GitHub defaults to `change_hook/github`.

* [GitHub help page on Post-Receive Hooks](https://help.github.com/articles/post-receive-hooks)
* [Buildbot Change Hooks](http://docs.buildbot.net/0.8.4p2/Change-Hooks.html)


### 3.3 Install Buildbot

Create the user `buildbot` and install the package:

    root@server:~# useradd -m -s /bin/bash buildbot
    root@server:~# apt-get install buildbot


Login as `buildbot` and create the master:

    root@server:~# su - buildbot
    buildbot@server:~$ buildbot create-master master


Each slave will run a different combination of Python and Django:

* Python 2.7 and Django 1.4
* Python 2.7 and Django 1.5
* Python 3.2 and Django 1.5

Create the virtualenvs:

    buildbot@server:~$ virtualenv slaves/py27-dj14
    buildbot@server:~$ source slaves/py27-dj14/bin/activate
    (py27-dj14)buildbot@server:~$ pip install "Django==1.4.5"
    (py27-dj14)buildbot@server:~$ deactivate

    buildbot@server:~$ virtualenv slaves/py27-dj15
    buildbot@server:~$ source slaves/py27-dj15/bin/activate
    (py27-dj15)buildbot@server:~$ pip install "Django==1.5.1"
    (py27-dj15)buildbot@server:~$ deactivate

    buildbot@server:~$ virtualenv -p python3 slaves/py32-dj15
    buildbot@server:~$ source slaves/py32-dj15/bin/activate
    (py32-dj15)buildbot@server:~$ pip install "Django==1.5.1"
    (py32-dj15)buildbot@server:~$ deactivate


Each slave runs inside their own virtualenv. The syntax of the ``buildslave`` command is as follows:

    buildslave create-slave <basedir> <master-addr/port> <name> <password>

Create the slaves:

    buildbot@server:~$ buildslave create-slave slaves/py27-dj14/slave localhost:9989 py27dj14 pass
    buildbot@server:~$ buildslave create-slave slaves/py27-dj15/slave localhost:9989 py27dj15 pass
    buildbot@server:~$ buildslave create-slave slaves/py32-dj15/slave localhost:9989 py32dj15 pass

This is the directory structure of `/home/buildbot`:

    buildbot@server:~$ tree -d -L 3
    .
    ├── master
    │   └── public_html
    └── slaves
        ├── py27-dj14
        │   ├── bin
        │   ├── include
        │   ├── lib
        │   ├── local
        │   └── slave
        ├── py27-dj15
        │   ├── bin
        │   ├── include
        │   ├── lib
        │   ├── local
        │   └── slave
        └── py32-dj15
            ├── bin
            ├── include
            ├── lib
            └── slave

    20 directories


### 3.4 Configure Buildbot in 3 steps

I approach the configuration in three steps to make a kind of a tutorial. Skip it if you already have a good understanding of Buildbot concepts. Then simply use the file `master.cfg.project+app+connected`. Otherwise go through the 3 steps.

In the first step Buildbot will build only the project. Then I'll add builds for the app. And at the end I'll add steps to trigger the build of the project after building the app. Read Continuous Integration of webapps with Buildbot to get a more wording introduction to this example.

*Note: In the following steps you will run Buidlbot from the command line. Use the script provided in the following up sections  to integrate it as part of the server startup process.* 

#### 3.4.1 Setup only the web project

Copy the `master.cfg.project` file to your `/home/buildbot/master/` directory and rename it to `master.cfg`. Then start the master and the three slaves:

    buildbot@@server:~$ buildbot start master
    
The command will output a bunch of log entries and finish with a line saying **The buildmaster appears to have (re)started correctly**. 

You will get enough information as to guess what's the problem if the command goes wrong. In such a case edit the `master.cfg` file, fix the bug and restart the service with:

    buildbot@server:~$ buildbot restart master


Visit the URL exposed by Buildbot: http://buildbot-server-ip:8010. Visit the waterfall and see that the 3 builders are offline. Start the slaves:

    buildbot@server:~$ source slaves/py27-dj14/bin/activate
    (py27-dj14)buildbot@server:~$ buildslave start slaves/py27-dj14/slave
    [...some log entries...]
    The buildslave appears to have (re)started correctly
    (py27-dj14)buildbot@server:~$ deactivate

    buildbot@server:~$ source slaves/py27-dj15/bin/activate
    (py27-dj15)buildbot@server:~$ buildslave start slaves/py27-dj15/slave
    [...some log entries...]
    The buildslave appears to have (re)started correctly
    (py27-dj15)buildbot@server:~$ deactivate

    buildbot@server:~$ source slaves/py32-dj15/bin/activate
    (py32-dj15)buildbot@server:~$ buildslave start slaves/py32-dj15/slave
    [...some log entries...]
    The buildslave appears to have (re)started correctly
    (py32-dj15)buildbot@server:~$ deactivate


Builders should be idle now in the web interface. Click on any of the builders and click on Force to immediately run a build.

Buildbot's master components (change source, schedulers, filters, build steps, builder factories and builders) required for this step are represented in the following figure:

![Buildbot configuration layout to build a Django web project](http://danir.us/media/pictures/2013/May/22/Buildbot-Django-Project.png)

#### 3.4.2 Add the setup for the web app

Buildbot allows you to build more than one software project. You can run as many as you want. The master configuration file for this step adds the Django app to the building process. Copy the `master.cfg.project+app` file to your `/home/buildbot/master/` directory and rename it to `master.cfg`. 

Edit the file and replace the web app URL with your own. Almost at the top of the file you will find the `repos` dictionary. Just edit the URL to satisfy the location you use:

    repos = {
        'webproject': {
            'url': '/home/git/django-sample-project.git',
            'branch': 'master'
        },
        'webapp': {
            'url': 'https://github.com/<yourGitHugUser>/django-sample-app.git',
            #'url': '/home/git/django-sample-app.git',
            'branch': 'master'
        },
    }

If you want to customise the SMTP settings to receive email notification on failed builds, adapt `smtp_kwargs` and remove the hash from the 3 lines defining the MailNotifier, down in the `status`.

Then restart the master (no need to restart the slaves):

    buildbot@@server:~$ buildbot restart master

The configuration doesn't change much, now:

* The status allows notification from GitHub.
* There's a new scheduler for the webapp.
* Two filters to see whether source code changes come from the project or the app. 
* Build steps to build the app.
* A build factory to putgroup together those new build steps.
* Three new builders for the app to say what steps will build the app and in which slave.

An image is worth a thousand words:

![Buildbot configuration layout to build a Django web project and a Django web app](http://danir.us/media/pictures/2013/May/21/Buildbot-Django-Project-and-App.png)


#### 3.4.3 Build the project after building the app

Are you looking for a Continuous Integration tool to build a project based on build results of other project? Buildbot does it hands down and Plugins-free.

The master configuration file for this step runs project builds once their app counterparts have run successfully. What does that mean?

* A web app source code change lands in Buildbot.
* Buildbot triggers the three app builders.
* The last step of each builder will trigger the project builder that runs under the very same conditions (Python+Django combination) only if the app did build successfully. 

Copy the `master.cfg.project+app+connected` file to your `/home/buildbot/master/` directory and rename it to `master.cfg`. 

The new configuration adds:

* Three triggerable schedulers that will be called from the app builders.
* Three new special build steps called Trigger, that will call the triggerable schedulers.
* One specific BuildFactory for each app Builder (rather than one for the three), as to add the Trigger step at the end of each BuildFactory. This way each app build triggers the corresponding project builder.

Again, an image's better to illustrates the new scenario:

![Buildbot configuration layout to build a Django web project and a Django web app, with triggerable schedulers](http://danir.us/media/pictures/2013/May/21/Buildbot-Django-Project-and-App-Triggerable.png)


### 3.5 Web server setup

Buildbot's web interface can be publicly reacheable through Apache, Nginx or any other web server with proxy capabilities. Checkout the simple sample virtual host configuration files provided for both Apache and Nginx:

 * [apache.vhost](https://github.com/danirus/buildbot-sample-conf/blob/master/apache.vhost)
 * [nginx.vhost](https://github.com/danirus/buildbot-sample-conf/blob/master/nginx.vhost)

The configuration makes the web server act as a proxy to pass all incoming requests to buildbot. It also setup restricted access to the path `/change_hook/github/` through which GitHub will post source code changes to Buildbot. Be sure that the list of IP addresses included are the same GitHub enables after setting up your WebHook.

### 3.6 Run at system startup

Use the following files with the init scripts provided by the Debian/Ubuntu package for Buildbot. They will make Buildbot run the slaves in their appropriate virtualenv:

* Copy `etc.default.buildmaster` to `/etc/default/buildmaster`
* Copy `etc.default.buildslave` to `/etc/default/buildslave`
* Copy `activate_venv.sh` to `/home/buildbot/slaves`

Doing so there won't be any conflict with Buildbot packages in case of updates from Debian/Ubuntu.

### 3.7 Build results images

