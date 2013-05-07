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

The following setup has been made in a fresh KVM virtual machine running Ubuntu Linux 12.04 with the following extra packages installed:

    apache2 python-pip python-virtualenv python3 git tree 


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
    buildbot.tac  master.cfg  master.cfg.sample  public_html/  state.sqlite

Create 3 virtualenvs and add a different version of Django to each of them:

    $ virtualenv --system-site-packages slaves/py27-dj14
    $ source slaves/py27-dj14/bin/activate
    (py27-dj14)$ pip install "Django==1.4.5"
    $ deactivate

    $ virtualenv --system-site-packages slaves/py27-dj15
    $ source slaves/py27-dj15/bin/activate
    (py27-dj15)$ pip install "Django==1.5.1"
    $ deactivate

    $ virtualenv -p python3 --system-site-packages slaves/py32-dj15
    $ source slaves/py32-dj15/bin/activate
    (py32-dj15)$ pip install "Django==1.5.1"
    $ deactivate

Create 3 slaves. Each of them will run inside a virtualenv to have access to a Django instance. The 3 virtualenvs have to get active on startup time right before launching the slaves.

The syntax of the ``buildslave`` command is as follows:

    $ buildslave create-slave <basedir> <master-addr/port> <name> <password>

I create Buildbot slaves in a directory inside the virtualenv:

    $ buildslave create-slave slaves/py27-dj14/slave localhost:9989 py27dj14 pass
    $ buildslave create-slave slaves/py27-dj15/slave localhost:9989 py27dj15 pass
    $ buildslave create-slave slaves/py32-dj15/slave localhost:9989 py32dj15 pass

This is the directory structure of `/home/buildbot`:

    $ tree -d -L 3
    .
    ├── master
    │   └── public_html
    └── slaves
     ├── py27-dj14
     │   ├── bin
     │   ├── include
     │   ├── lib
     │   ├── local
     │   └── slave
     ├── py27-dj15
     │   ├── bin
     │   ├── include
     │   ├── lib
     │   ├── local
     │   └── slave
     └── py32-dj15
	 ├── bin
	 ├── include
	 ├── lib
	 └── slave

    20 directories


### 3.3 Setup the app repository in GitHub

For the purpose of this example you can clone [django-sample-app](https://github.com/danirus/django-sample-app). You will later add the URL of your copy in GitHub to your Buildbot configuration.


### 3.4 Setup the project repository in the server

[Django-sample-project](https://github.com/danirus/django-sample-project) is an implementation of the official [Django tutorial](https://docs.djangoproject.com/en/1.5/intro/tutorial01/) with an extra dependency on [django-sample-app](https://github.com/danirus/django-sample-app) and a couple of simple test cases. 

One of the test cases makes implicit use of the functionality provided by django-sample-app. Given that changes in the sample app may damage the project there will be a test case to cover such a situation. 

Buildbot configuration will run the project's unittests right after running app's unittests. If either app's or project's unittests fail a notification will be sent in order to fix the bug.

#### 3.4.1 Create git user/group and grant access to your user

Before creating the self hosted repository I assume you have a git user/group in your server with the home directory under ``/home/git``. In the server:

    # adduser --system --home /home/git --shell /bin/bash \
              --gecos "GIT Source Code Management" --group \
              --disabled-password git
    # chmod g+w /home/git/ -R 

Copy your ssh ``id_rsa.pub`` key from your local machine to the server's ``/home/git/.ssh/authorized_keys`` and add your username to the git group in ``/etc/groups``. 

#### 3.4.2 Create the git repository in the server

Then clone [django-sample-project](https://github.com/danirus/django-sample-project), create a bare Git repository from it and upload it to your server:

    $ git clone git://github.com/danirus/django-sample-project.git
    $ git clone --bare django-sample-project/.git/ /tmp/django-sample-project.git
    $ scp -r /tmp/django-sample-project.git git@yourserverip:/home/git/django-sample-project.git 

#### 3.4.3 Create the post-receive hook

Create a new file ``post-receive`` in the server's git repository, in the ``/home/git/django-sample-project.git/hooks/`` directory, with the following content:

    

#### 3.4.4 Clone the repository in your desktop

Once the bare repository has been copied to the server and you have access to it, clone the repository in your desktop. Later you will make changes to the repository and push them to trigger Buildbot builds:

### 3.5 Setup Apache VirtualHosts

