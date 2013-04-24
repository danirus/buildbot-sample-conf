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

The following setup has been made in a fresh KVM virtual machine running Linux Ubuntu 12.04 with the following packages installed:

    apache2 python-pip python-virtualenv git

### 3.1 Install Buildbot

First create the user `buildbot` and then install the package. If you do it in the other way round be sure to have an operative user `buildbot`. Otherwise delete the user and create it again as follows:

    # useradd -m -s /bin/bash buildbot
    # apt-get install buildbot


### 3.2 Create master, virtualenvs, and slaves

Do login as `buildbot`. Then create  the master:

    # su - buildbot
    $ buildbot create-master master
    mkdir /home/buildbot/master
    chdir /home/buildbot/master
    creating master.cfg.sample
    populating public_html/
    creating Makefile.sample
    creating database
    buildmaster configured in /home/buildbot/master

Logged in as `buildbot` I create 3 `virtualenv <http://www.virtualenv.org>`_s. Along with virtualenv I use `virtualenvwrapper <http://doughellmann.com/2008/05/virtualenvwrapper.html>`_, a set of useful command line extensions to virtualenv. Each virtualenv will have