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
 9. Buildbot has to show a public web with app's builds results.
 10. Buildbot has to show a private web with both app's and project's builds results.


## 2. Solution

 1. Buildbot's master and slave will live in the same machine.
 2. There will be 3 Python virtualenv to support Django v1.4/v1.5 under Python v2.7, and Django v1.5 under Python v3.2.
 3. Buildbot will have 3 slaves one per virtualenv.
 4. Virtualenvs will get active at OS startup time, before launching slaves.
 5. Project's repository in the in-house server will get a new `post-receive` hook script that will notify Buildbot on changes.
 6. Buildbot will accept HTTP POST requests from GitHub.
 7. App's GitHub repository will get a new WebHook URL pointing to Buildbot's web interface.
 8. Apache or Nginx will handle requests to both public and private Buildbot web interfaces.


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

[Django-sample-project](https://github.com/danirus/django-sample-project) represents the private Django project. It's an implementation of the official [Django tutorial](https://docs.djangoproject.com/en/1.5/intro/tutorial01/).

The following steps create the private in-house Git repository for the project.


#### 3.1.1 Create the git user and group

For the sake of this example the Git repository for the project lives in the same server as Buildbot. Create a git user and group, and add your username to the git group: 

    root@server:~# useradd -m -s /bin/bash git
    root@server:~# usermod -G git youruser


#### 3.1.2 Create the git repository in the server

Clone a bare copy of [django-sample-project](https://github.com/danirus/django-sample-project) to start off the in-house Git repository for the project:

    root@server:~# su - git
    git@server:~$ git clone git://github.com/danirus/django-sample-project.git


#### 3.1.3 Create the post-receive hook

Copy the ``post-receive`` file (that sits close to this very README.md you are reading) to ``/home/git/django-sample-project.git/hooks/``. The post-receive hook runs a script that will notify buildbot when changes hit the project's repository.

If your Buildbot's master lives in a different host:port add the ``--master ipaddress:port`` option to the hook along with the --repository option.

With this hook in place Buildbot will get notified on every ``git push`` to the repository.


### 3.2 Setup the Github repository for the Django app

This step requires the server to be reacheable from the outside world as GitHub will post a HTTP request to Buildbot. If it's not (because you are playing around with a VM, just do the same with the app as what you've done with the project).

Fork [django-sample-app](https://github.com/danirus/django-sample-app) in your own GitHub account. Then go to the repository settings, click on Service Hooks, and WebHook URLS. Add the URL of your Buildbot master with the path to the GitHub hook:

    http://buildbot.myservice.info/change_hook/github

Buildbot's path for GitHub defaults to `change_hook/github`.

* [GitHub help page on Post-Receive Hooks](https://help.github.com/articles/post-receive-hooks)
* [Buildbot Change Hooks](http://docs.buildbot.net/0.8.4p2/Change-Hooks.html)


### 3.3 Install Buildbot

Create the user `buildbot` and install the package:

    # useradd -m -s /bin/bash buildbot
    # apt-get install buildbot


Login as `buildbot` and create the master:

    # su - buildbot
    $ buildbot create-master master


Each slave will run a different combination of Python and Django:

* Python 2.7 and Django 1.4
* Python 2.7 and Django 1.5
* Python 3.2 and Django 1.5

Create the virtualenvs:

    $ virtualenv slaves/py27-dj14
    $ source slaves/py27-dj14/bin/activate
    (py27-dj14)$ pip install "Django==1.4.5"
    $ deactivate

    $ virtualenv slaves/py27-dj15
    $ source slaves/py27-dj15/bin/activate
    (py27-dj15)$ pip install "Django==1.5.1"
    $ deactivate

    $ virtualenv -p python3 slaves/py32-dj15
    $ source slaves/py32-dj15/bin/activate
    (py32-dj15)$ pip install "Django==1.5.1"
    $ deactivate


Each slave runs inside their own virtualenv. The syntax of the ``buildslave`` command is as follows:

    $ buildslave create-slave <basedir> <master-addr/port> <name> <password>

Create the slaves:

    $ buildslave create-slave slaves/py27-dj14/slave localhost:9989 py27dj14 pass
    $ buildslave create-slave slaves/py27-dj15/slave localhost:9989 py27dj15 pass
    $ buildslave create-slave slaves/py32-dj15/slave localhost:9989 py32dj15 pass

This is the directory structure of `/home/buildbot`:

    $ tree -d -L 3
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

### 3.4.1 Setup only the web project

### 3.4.2 Add the setup for the web app

### 3.4.3 Build the project after building the app

### 3.5 Web servers setup

#### 3.5.1 Apache

#### 3.5.2 Nginx

