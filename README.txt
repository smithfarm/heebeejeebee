Dockerfiles for generating ceph tarballs in OBS/IBS
===================================================


What is this?
-------------

This is a project that automates the process of generating ceph tarballs from
git repos in OBS/IBS projects.


Who might want to use this?
---------------------------

Anyone who builds ceph RPMs in OBS/IBS and would like to generate the tarballs
from a git repo in a pristine environment. Also, it helps if you are not a
Docker-hater.


What are the prequisites?
-------------------------

Docker or Podman must be installed and working in your environment. You will
also need an ~/.oscrc file corresponding to an OBS/IBS user with maintainer rights
on the OBS/IBS project you intend to build in.


How do I set up an heebeejeebee environment?
--------------------------------------------

Preparatory steps

    git clone https://github.com/smithfarm/heebeejeebee
    cp ~/.oscrc heebeejeebee/oscrc
    cd heebeejeebee

Usage - Docker

    ./rebuild-image.sh
    ./tarball.sh --help

Usage - Podman

    sudo ln -s /usr/bin/podman /usr/bin/docker
    sudo ./rebuild-image.sh
    sudo ./tarball.sh --help

In other words, when using Podman, run "rebuild-image.sh" and "tarball.sh" via sudo.


Example
-------

Let's say you have ceph in an OBS project called "foo:bar:blatz", and you 
have a ceph branch "wip-foo" in a GitHub repo "blatz/ceph". You are running
heebeejeebee with Podman. Your username is "bar" and you have passwordless
sudo privileges.

    sudo bash build.sh --obs \
         --project foo:bar:blatz \
         --repo https://github.com/blatz/ceph.git \
         --branch wip-foo

This will:

1. checkout the "foo:bar:blatz/ceph" package from OBS
2. clone the "https://github.com/blatz/ceph.git" repo
3. generate a new tarball, specfile, etc. from the tip of branch "wip-foo"

The new state of "foo:bar:blatz/ceph" will be saved on your local drive
in /home/bar (configurable with --outputdir).


Why two container images instead of just one?
---------------------------------------------

When working on entrypoint.sh, it's faster when it has a dedicated "run" image.
Otherwise, one has to rebuild the base image every time entrypoint.sh changes.


This @!*%#! filled up my disk!
------------------------------

Run:

    docker system prune -f

