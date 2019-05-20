#!/bin/bash
set -ex

SCRIPTNAME=$(basename ${0})
DOCKERFILE=$(mktemp)

function cleanup {
    rm -f $DOCKERFILE
}

trap cleanup EXIT

function usage {
    set +x
    echo "$SCRIPTNAME - generate ceph tarballs using Dockerfiles"
    echo
    echo "Options:"
    echo "    --branch        Branch to pass to checkin.sh (defaults to \"master\")"
    echo "    --help          Display this usage message"
    echo "    --ibs           Use IBS"
    echo "    --obs           Use OBS (the default)"
    echo "    --outputdir     Directory under which to create the target osc checkout (defaults to \"$HOME\")"
    echo "    --project       IBS/OBS project (defaults to \"filesystems:ceph:octopus:upstream\")"
    echo "    --rebuild-base  Rebuild the base container"
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

TEMP=$(getopt -o h --long "branch:,help,ibs,project:,obs,rebuild-base,repo:" -n 'build.sh' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

BRANCH="master"
BUILD_SERVICE="OBS"
IBS=""
OBS="--obs"
OUTPUTDIR="$HOME"
PROJECT="filesystems:ceph:octopus:upstream"
REBUILD_BASE=""
REPO="https://github.com/ceph/ceph.git"
while true ; do
    case "$1" in
        -h|--help) usage ;;    # does not return
        --branch) shift ; BRANCH="$1" ; shift ;;
        --ibs) IBS="$1" ; OBS="" ; BUILD_SERVICE="IBS" ; shift ;;
        --obs) OBS="$1" ; IBS="" ; BUILD_SERVICE="OBS" ; shift ;;
        --outputdir) shift ; OUTPUTDIR="$1" ; shift ;;
        --project) shift ; PROJECT="$1" ; shift ;;
        --rebuild-base) REBUILD_BASE="$1" ; shift ;;
        --repo) shift ; REPO="$1" ; shift ;;
        --) shift ; break ;;
        *) echo "Internal error" ; false ;;
    esac
done

test -d oscrc || cp ~/.oscrc oscrc

if [ "$REBUILD_BASE" ] ; then
    docker build \
        --no-cache \
        --tag make-rpm-base \
        --file ./Dockerfile-base \
        .
    exit 0
fi

# expand repo shortcuts
# FIXME: use bash regex instead of perl here
if [ "$(perl -e '"'"$REPO"'" =~ m/(^\w+$)/; print "$1\n";')" ] ; then
    REPO="https://github.com/$REPO/ceph.git"
elif [ "$(perl -e '"'"$REPO"'" =~ m/(^\w+\/\w+$)/; print "$1\n";')" ] ; then
    REPO="https://github.com/$REPO.git"
fi

set +x
echo "===================================================="
echo "BUILD_SERVICE ->$BUILD_SERVICE<-"
echo "PROJECT       ->$PROJECT<-"
echo "OUTPUTDIR     ->$OUTPUTDIR<-"
echo "REPO          ->$REPO<-"
echo "BRANCH        ->$BRANCH<-" 
echo "===================================================="
set -x

cp Dockerfile-rpm $DOCKERFILE
test "$BRANCH" && sed -i -e "s/((BRANCH))/$BRANCH/g" $DOCKERFILE
test "$IBS" && sed -i -e 's/((OSC))/$iosc/g' $DOCKERFILE
test "$OBS" && sed -i -e 's/((OSC))/$oosc/g' $DOCKERFILE
test "$PROJECT" && sed -i -e "s/((PROJECT))/$PROJECT/g" $DOCKERFILE
test "$REPO" && sed -i -e "s#((REPO))#$REPO#g" $DOCKERFILE

docker build \
    --no-cache \
    --tag make-ceph-tarball \
    --file $DOCKERFILE \
    .

if [ -d "$OUTPUTDIR/$PROJECT" ] ; then
    echo "$OUTPUTDIR/$PROJECT already exists - blowing it away"
    rm -rf $OUTPUTDIR/$PROJECT
fi

docker run -v $OUTPUTDIR:/mnt make-ceph-tarball:latest cp -a /home/smithfarm/$PROJECT /mnt

rm -f $DOCKERFILE

test -d $OUTPUTDIR/$PROJECT/ceph
echo "New files in ${OUTPUTDIR}/${PROJECT}/ceph"
ls -l ${OUTPUTDIR}/${PROJECT}/ceph
