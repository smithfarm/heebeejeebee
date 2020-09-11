#!/bin/bash

SCRIPTNAME=$(basename ${0})
OUTPUTDIR="/home/$(logname)"
test -d "$OUTPUTDIR" || OUTPUTDIR="$HOME"

function usage {
    echo "$SCRIPTNAME - generate ceph tarballs using Dockerfiles"
    echo
    echo "Options:"
    echo "    --branch        Branch to pass to checkin.sh (defaults to \"master\")"
    echo "    --help          Display this usage message"
    echo "    --ibs           Use IBS"
    echo "    --obs           Use OBS (the default)"
    echo "    --outputdir     Directory under which to create the target osc checkout (defaults to \"$OUTPUTDIR\")"
    echo "    --project       IBS/OBS project (defaults to \"filesystems:ceph:octopus:upstream\")"
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

TEMP=$(getopt -o ho: --long "branch:,help,ibs,outputdir:,project:,obs,repo:" -n 'build.sh' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

BRANCH="master"
BUILD_SERVICE="OBS"
IBS=""
OBS="--obs"
BS_OPT=""
PROJECT="filesystems:ceph:octopus:upstream"
REPO="https://github.com/ceph/ceph.git"
while true ; do
    case "$1" in
        -h|--help) usage ;;    # does not return
        --branch) shift ; BRANCH="$1" ; shift ;;
        --ibs) IBS="$1" ; OBS="" ; BS_OPT="$1" ; BUILD_SERVICE="IBS" ; shift ;;
        --obs) OBS="$1" ; IBS="" ; BS_OPT="$1" ; BUILD_SERVICE="OBS" ; shift ;;
        -o|--outputdir) shift ; OUTPUTDIR="$1" ; shift ;;
        --project) shift ; PROJECT="$1" ; shift ;;
        --repo) shift ; REPO="$1" ; shift ;;
        --) shift ; break ;;
        *) echo "Internal error" ; false ;;
    esac
done

echo "=============================================="
echo "BUILD_SERVICE $BUILD_SERVICE"
echo "PROJECT       $PROJECT"
echo "REPO          $REPO"
echo "BRANCH        $BRANCH" 
echo "OUTPUTDIR     $OUTPUTDIR"
echo "=============================================="

set -x
sudo rm -rf $OUTPUTDIR/$PROJECT/ceph
docker run \
    -v "$OUTPUTDIR:/home/smithfarm/output" \
    hbjb-run:latest \
    "$BS_OPT" --project "$PROJECT" --repo "$REPO" --branch "$BRANCH"
ls -l $OUTPUTDIR/${PROJECT}/ceph
set +x

if [ -d $OUTPUTDIR/$PROJECT/ceph ] ; then
    echo "New content in $OUTPUTDIR/${PROJECT}/ceph"
    exit 0
else
    echo "tarball.sh: failed to generate a new tarball"
    exit 1
fi
