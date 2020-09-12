#!/bin/bash

export LANG=en_US.UTF-8
OOSC="osc -A https://api.opensuse.org/"
IOSC="osc -A https://api.suse.de/"
OSC="$OOSC"
SCRIPTNAME=$(basename ${0})

function usage {
    set +x
    echo "$SCRIPTNAME - generate ceph tarballs using Dockerfiles"
    echo
    echo "Options:"
    echo "    --branch        Branch to pass to checkin.sh (defaults to \"master\")"
    echo "    --help          Display this usage message"
    echo "    --ibs           Use IBS"
    echo "    --obs           Use OBS (the default)"
    echo "    --package       project package (defaults to \"ceph\")"
    echo "    --project       IBS/OBS project (defaults to \"filesystems:ceph:master:upstream\")"
    echo "    --repo          Repo to pass to checkin.sh (defaults to \"https://github.com/ceph/ceph.git\")"
    echo
    echo "Note: in addition to a full URL, the --repo option understands shortcuts:"
    echo
    echo "shortcut            expands to"
    echo "--------            ----------"
    echo "foo                 https://github.com/foo/ceph.git"
    echo "foo/ceph            https://github.com/foo/bar.git"
    exit 1
}

TEMP=$(getopt -o h \
  --long "branch:,help,ibs,project:,obs,rebuild-base,repo:,package:" \
  -n 'entrypoint.sh' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

BRANCH="master"
BUILD_SERVICE="OBS"
IBS=""
OBS="--obs"
PACKAGE="ceph"
PROJECT="filesystems:ceph:master:upstream"
REPO="https://github.com/ceph/ceph.git"
while true ; do
    case "$1" in
        -h|--help) usage ;;    # does not return
        --branch) shift ; BRANCH="$1" ; shift ;;
        --ibs) IBS="$1" ; OBS="" ; OSC="$IOSC" ; BUILD_SERVICE="IBS" ; shift ;;
        --obs) OBS="$1" ; IBS="" ; OSC="$OOSC" ; BUILD_SERVICE="OBS" ; shift ;;
        --package) shift ; PACKAGE="$1" ; shift ;;
        --project) shift ; PROJECT="$1" ; shift ;;
        --repo) shift ; REPO="$1" ; shift ;;
        --) shift ; break ;;
        *) echo "Internal error" ; false ;;
    esac
done

# expand repo shortcuts
# FIXME: use bash regex instead of perl here
if [ "$(perl -e '"'"$REPO"'" =~ m/(^\w+$)/; print "$1\n";')" ] ; then
    REPO="https://github.com/$REPO/ceph.git"
elif [ "$(perl -e '"'"$REPO"'" =~ m/(^\w+\/\w+$)/; print "$1\n";')" ] ; then
    REPO="https://github.com/$REPO.git"
fi


cat <<EOF
------------------------
osc version:  $($OSC --version)
    project:  $PROJECT
    package:  $PACKAGE
       repo:  $REPO
     branch:  $BRANCH
------------------------
EOF


# build tarball in /builder/$PROJECT/ceph (inside the container)
set -ex
rm -rf $PROJECT/$PACKAGE
$OSC co $PROJECT $PACKAGE
pushd $PROJECT/$PACKAGE
bash checkin.sh --repo "$REPO" --branch "$BRANCH"
popd

# copy the tarball, etc. from /builder/$PROJECT/ceph to
# /builder/output/$PROJECT/ceph - this directory is associated
# with the OUTPUTDIR from tarball.sh via "docker -v"
#
if [ -d output/$PROJECT ] ; then
    echo "entrypoint.sh: /builder/output/$PROJECT already exists - bailing out!"
    exit 1
else
    sudo mkdir output/$PROJECT
    sudo cp -a $PROJECT/$PACKAGE output/$PROJECT
fi
