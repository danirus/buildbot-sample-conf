# django-simple

This document describes how to do continuous integration of a Django app and a Django project. It contains configuration files for Buildbot, Git and Apache.

## 1. Scenario

 1. One public Django pluggable application.
 2. One private Django project that uses the previous application.
 3. Buildbot has to run tests for both, the app and the project.
 4. Buildbot will build the app when changes hit app's repository.
 5. Buildbot will build the project when changes hit project's repository and right after building the app.
 6. App's repository is public and hosted in GitHub.
 7. Project's repository is private and hosted in an in-house server.
 8. App and project have to be build under supported versions of Python/Django.
 9. Buildbot has to show a public web with app's builds results.
 10. Buildbot has to show a private web with both app's and project's builds results.


## 2. Solution

 1. Buildbot's master and slave will live in the same machine.
 2. There will be 3 Python virtualenv to support Django v1.4/v1.5 under Python v2.7, and Django v1.5 under Python v3.2.
 3. Buildbot will have 3 slaves one per virtualenv.
 4. Virtualenvs will get active at OS startup time, before launching slaves.
 5. Apache will be the web server listening on port 80, and will handle requests to both public and private Buildbot web interfaces.
 6. Buildbot will accept POST requests from GitHub through Apache.
 7. App's GitHub repository will get a new WebHook URL pointing to the web server.
 8. Project's repository in the in-house server will get a new `post-receive` hook script that will notify Buildbot on changes.


## 3. Solution setup

The following setup has been made in a fresh KVM virtual machine running Ubuntu Server 12.04 with the following extra packages installed:

    apache2 python-pip python-virtualenv python3 git tree 


### 3.1 Install Buildbot

First create the user `buildbot` and then install the package. If you do it in the other way round be sure to have an operative user `buildbot`. Otherwise delete the user and create it again as follows:

    # useradd -m -s /bin/bash buildbot
    # apt-get install buildbot


#### 3.1.1 Create the master

Do login as `buildbot`, and then create  the master:

    # su - buildbot
    $ buildbot create-master master

Copy the `master.cfg` file (available in this very directory, close to the README.md file you are reading) into the master directory created by buildbot, near `master.cfg.sample`.

    $ ls -F master/
    buildbot.tac  master.cfg  master.cfg.sample  public_html/  state.sqlite


#### 3.1.2 Create the virtualenvs

Each slave will run a different combination of Python/Django to cover the supported releases of the latter. These are the combinations to reproduce:

* Python 2.7 and Django 1.4
* Python 2.7 and Django 1.5
* Python 3.2 and Django 1.5

Let's create the three virtualenvs:

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

The 3 virtualenvs have to get active on startup time right before launching the slaves. We will see that later.


#### 3.1.3 Create the slaves

Each of the 3 slaves will run inside their own virtualenv. The syntax of the ``buildslave`` command is as follows:

    $ buildslave create-slave <basedir> <master-addr/port> <name> <password>

Each slave will live in a directory inside the virtualenv directory structure:

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


### 3.2 Setup the web project repository in the server

[Django-sample-project](https://github.com/danirus/django-sample-project) is an implementation of the official [Django tutorial](https://docs.djangoproject.com/en/1.5/intro/tutorial01/) with an extra dependency on [django-sample-app](https://github.com/danirus/django-sample-app) and a couple of simple test cases. 

For this example we use the code of [Django-sample-project](https://github.com/danirus/django-sample-project) to represent the project.


#### 3.2.1 Create the git user and group

The git repository of the project will live in the same server as Buildbot. Create a git user and group in the server and use ``/home/git`` as the home directory:

    # adduser --system --home /home/git --shell /bin/bash \
              --gecos "GIT Source Code Management" --group \
              --disabled-password git

Add your username in the server to the git group in ``/etc/groups`` and eventually copy your ssh key to ``/home/git/.ssh/authorized_keys`` to be able to transfer the repository to the server. 


#### 3.2.2 Create the git repository in the server

Clone [django-sample-project](https://github.com/danirus/django-sample-project), create a bare Git repository from it and upload it to the server:

    $ git clone git://github.com/danirus/django-sample-project.git
    $ git clone --bare django-sample-project/.git/ /tmp/django-sample-project.git
    $ scp -r /tmp/django-sample-project.git git@server:/home/git/django-sample-project.git 

Once the repository is in the server you can clone it in your desktop. Later you will make changes to the repository and push them to trigger Buildbot's builds.

    $ git clone ssh://you@server/home/git/django-sample-project.git private-project


#### 3.2.3 Create the post-receive hook

Create a new file ``post-receive`` in the server's git repository. Copy the ``post-receive`` file (in the same directory as this very README.md file) in ``/home/git/django-sample-project.git/hooks/``. The post-receive hook runs a buildbot script that notifies buildbot when changes hit the repository:  

    #!/bin/bash
    while read oldrev newrev refname
    do
	echo $oldrev $newrev $refname | /usr/bin/python /usr/share/buildbot/contrib/git_buildbot.py --repository file:///home/git/django-sample-project.git
    done

If Buildbot's master is in a different host:port add ``--master ipaddress:port`` along with the --repository option.

Now Buildbot will get notified with every ``git push`` to the web project repository.


### 3.3 Setup the web app repository in GitHub

Fork [django-sample-app](https://github.com/danirus/django-sample-app). Once forked go to your repository settings, click on Service Hooks, and WebHook URLS. Then add the URL of your Buildbot master with the path to the GitHub hook:

    http://buildbot.example.com/change_hook/github

The path to Buildbot's GitHub hook defaults to `change_hook/github`. 

* Checkout the [GitHub help page on Post-Receive Hooks](https://help.github.com/articles/post-receive-hooks) if you need help with GitHub Web Hooks.
* Checkout the [Change Hooks](http://docs.buildbot.net/0.8.4p2/Change-Hooks.html) page of the Buildbot Manual to find out more on the GitHub hook.


### 3.4 Setup Buildbot

Buildbot's ``master.cfg`` file puts together all the components of a Buildbot environment:

* Slaves
* Source code changes
* Schedulers
* Build steps
* Builders
* Status interfaces (Web, Email, IRC...)

The following sections go over the details in the [master.cfg](https://raw.github.com/danirus/buildbot-sample-conf/master/django-simple/master.cfg) file (available in this very directory). You copied the file in the step 3.1.1 to the master directory.

After reading the next sections open the file and read the comments.

#### 3.4.1 Slaves



#### 3.4.2 Source code changes

#### 3.4.3 Schedulers and filters

#### 3.4.5 Build steps and build factories

#### 3.4.6 Builders

#### 3.4.7 Status interfaces

##### 3.4.7.1 Web Interface

##### 3.4.7.2 Mailer

### 3.5 Setup Apache VirtualHosts

