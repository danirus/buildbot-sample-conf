# django-simple

This directory contains configuration files for Buildbot and Apache.

## 1. Scenario

 1. One public FOSS sample Django app.
 2. One private Django project that uses the app.
 3. Buildbot will run tests suites for both, the app and the project.
 4. App's unittests will run when new changes hit app's repository.
 5. Project's unittests will run when new changes hit project's repository and right after app's unittests have run.
 6. App's repository is public and hosted in GitHub.
 7. Project's repository is private and hosted in an in-house server.
 8. App and project have to run unittests using the most 3 recent versions of Django.
 9. A web available to the public will show how the app builds.
 10. A private web will show how the app and the project build.


## 2. Solution

 1. Buildbot's master and slave will live in the same machine.
 2. There will be 3 python virtualenv, each using a different version of Django.
 3. Buildbot will have 3 slaves one per virtualenv.
 4. Virtualenvs will get active at OS startup time, before launching slaves.
 5. Apache will be the web server listening on port 80, and will handle requests to both public and private Buildbot web interfaces.
 6. Apache and Buildbot will accept POST requests from GitHub.
 7. App's GitHub repository will get a new WebHook URL pointing to our web server.
 8. Project's repository in the in-house server will get a new `post-receive` hook script that will notify Buildbot on changes.


## 3. Solution setup

The following setup has been made in a fresh KVM virtual machine running Linux Debian 7.0 (Wheezy) with the following packages installed:

    apache2 python-pip python-virtualenv git tree

### 3.1 Install Buildbot

First create the user `buildbot` and then install the package. If you do it in the other way round be sure to have an operative user `buildbot`. Otherwise delete the user and create it again as follows:

    # useradd -m -s /bin/bash buildbot
    # apt-get install buildbot


### 3.2 Create master, virtualenvs, and slaves

Do login as `buildbot`, and then create  the master:

    # su - buildbot
    $ buildbot create-master master

Copy the `master.cfg` file available under the same dir as this README.md file you are reading into the master directory created by buildbot, near `master.cfg.sample`.

    $ ls -F master/
    buildbot.tac  Makefile.sample  master.cfg  master.cfg.sample  public_html/  state.sqlite

Create 3 virtualenvs and add a different version of Django to each of them:

    $ virtualenv --system-site-packages slaves/py27-dj13
    $ source slaves/py27-dj13/bin/activate
    (py27-dj13)$ pip install "Django==1.3.7"
    $ deactivate

    $ virtualenv --system-site-packages slaves/py27-dj14
    $ source slaves/py27-dj14/bin/activate
    (py27-dj14)$ pip install "Django==1.4.5"
    $ deactivate

    $ virtualenv --system-site-packages slaves/py27-dj15
    $ source slaves/py27-dj15/bin/activate
    (py27-dj15)$ pip install "Django==1.5.1"
    $ deactivate

Create 3 slaves. Each of them will run inside a virtualenv to have access to a Django instance. The 3 virtualenvs have to get active on startup time right before launching the slaves. 

I create Buildbot slaves in a directory inside the virtualenv:

    $ buildslave create-slave slaves/py27-dj13/slave localhost:9989 django13 pass
    $ buildslave create-slave slaves/py27-dj14/slave localhost:9989 django14 pass
    $ buildslave create-slave slaves/py27-dj15/slave localhost:9989 django15 pass

This is the directory structure of `/home/buildbot`:

    $ tree -d -L 3
    .
    ├── master
    │   └── public_html
    └── slaves
     ├── py27-dj13
     │   ├── bin
     │   ├── include
     │   ├── lib
     │   ├── local
     │   └── slave
     ├── py27-dj14
     │   ├── bin
     │   ├── include
     │   ├── lib
     │   ├── local
     │   └── slave
     └── py27-dj15
	 ├── bin
	 ├── include
	 ├── lib
	 ├── local
	 └── slave

    21 directories


### 3.3 Setup the app repository in GitHub

For the purpose of this example you can clone [django-sample-app](https://github.com/danirus/django-sample-app). You will later add the URL of your copy in GitHub to your Buildbot configuration.


### 3.4 Setup the project repository in the server

[Django-sample-project](https://github.com/danirus/django-sample-project) is the implementation of the official [Django tutorial](https://docs.djangoproject.com/en/1.5/intro/tutorial01/). It has an extra dependency on [django-sample-app](https://github.com/danirus/django-sample-app) and a few simple test cases. 

One of the test cases makes implicit use of the functionality provided by django-sample-app. Given that changes in the sample app may potentially damage the project, one of the project's test cases will cover such a situation. 

Buildbot's configuration will run project's tests right after running app's. If either app's or project's tests fail a notification will be sent and your operations team will be able to hold the changes in development until the bug is fixed.

Clone [django-sample-project](https://github.com/danirus/django-sample-project), create a bare Git repository from it and upload it to your server.

    $ git clone git://github.com/danirus/django-sample-project.git
    $ git clone --bare django-sample-project/.git/ /tmp/django-sample-project.git
    $ scp -r /tmp/django-sample-project.git server:/home/git/django-sample-project.git 


### 3.5 Setup Apache VirtualHosts

