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

Docker must be installed and working in your environment. You will also need an
.oscrc file corresponding to an OBS/IBS user with maintainer rights on the
OBS/IBS project you intend to build in.


How do I use this?
------------------

I can't tell you that, but I'll give you a hint: Clone this repo. Change your
working directory to the clone directory (i.e. "cd into the clone"). Copy your
.oscrc file into the local clone using the command

    cp ~/.oscrc ./oscrc

Build the "make-rpm-base" container:

    ./build.sh --rebuild-base

Finally, run: 

    ./build.sh --help
