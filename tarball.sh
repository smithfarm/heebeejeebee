#!/bin/bash

set -e

SCRIPTNAME="$(basename "${0}")"
HEEBEEJEEBEE_DIRECTORY="$HOME/.heebeejeebee"
HEEBEEJEEBEE_IMAGE_PATH="registry.suse.de/devel/storage/7.0/testing/containers"
HEEBEEJEEBEE_IMAGE_NAME="heebeejeebee"
BRANCH="master"
BUILD_SERVICE="OBS"
CONTAINER_IMAGE="$HEEBEEJEEBEE_IMAGE_PATH/$HEEBEEJEEBEE_IMAGE_NAME"
IBSOBS="--obs"
OUTPUTDIR="/home/$(logname)"
test -d "$OUTPUTDIR" || OUTPUTDIR="$HOME"
PROJECT="filesystems:ceph:master:upstream"
REPO="https://github.com/ceph/ceph.git"

function usage {
    echo "$SCRIPTNAME - run heebeejeebee container to generate a ceph tarball"
    echo
    echo "Options:"
    echo "    --branch           Branch to pass to heebeejeebee (defaults to \"$BRANCH\")"
    echo "    --help             Display this usage message"
    echo "    --ibs              Use IBS"
    echo "    --non-interactive  Do not require any user interaction"
    echo "    --obs              Use OBS (the default)"
    echo "    --outputdir        Directory under which to create the target osc checkout (defaults to \"$OUTPUTDIR\")"
    echo "    --pull             Pull the latest heebeejeebee container image"
    echo "    --project          IBS/OBS project (defaults to \"$PROJECT\")"
    echo "    --repo             Repo to pass to checkin.sh (defaults to \"$REPO\")"
    echo
    echo "Note: in addition to a full URL, the --repo option understands shortcuts:"
    echo
    echo "shortcut            expands to"
    echo "--------            ----------"
    echo "foo                 https://github.com/foo/ceph.git"
    echo "foo/ceph            https://github.com/foo/bar.git"
    exit 1
}

function _command_exists {
    local cmd="$1"
    type "$cmd" > /dev/null 2>&1
}

function assert_command_exists {
    local cmd="$1"
    if _command_exists "$1" ; then
        true
    else
        error_exit "This script needs $cmd, which is not installed."
    fi  
}

function error_exit {
    local message="$1"
    echo "($SCRIPTNAME) ERROR: $message"
    exit 1
}

function podman_pull {
    set -x
    test "$CONTAINER_IMAGE"
    podman pull "$CONTAINER_IMAGE"
    set +x
}

function vet_oscrc {
    local oscrc_ok
    oscrc_ok="yes"
    if grep -q api.suse.de "$HOME/.oscrc" ; then
        true
    else
        echo "ERROR: I'm missing a [https://api.suse.de] stanza in your ~/.oscrc file!"
    fi
    if grep -q api.opensuse.org "$HOME/.oscrc" ; then
        true
    else
        echo "ERROR: I'm missing a [https://api.opensuse.org] stanza in your ~/.oscrc file!"
    fi
    if [ "$oscrc_ok" ] ; then
        true
    else
        error_exit "heebeejeebee cannot work with your ~/.oscrc file. Sorry!"
    fi
}

function vet_podman_version {
    local raw_podman_version
    local podman_major_version
    raw_podman_version="$(podman --version)"
    set -x
    podman_major_version="$(perl -e '"'"$raw_podman_version"'" =~ m/podman version ([0-9])/; print "$1\n";')"
    set +x
    if [ "$podman_major_version" -ge "2" ] ; then
        echo "We have podman version $podman_major_version. Good."
    else
        set -x
        podman --version
        set +x
        error_exit "What kind of podman is this? I need podman version 2 or above!"
    fi
}

# create ~/.heebeejeebee directory so we can bind-mount it into the container
# later

function heebeejeebee_cleanup {
    rm -f "$HEEBEEJEEBEE_DIRECTORY/.oscrc"
}

if [ -d "$HOME" ] ; then
    true
else
    error_exit "This script needs \$HOME to be set to your home directory."
fi

if [ -e "$HEEBEEJEEBEE_DIRECTORY" ] ; then
    if [ -d "$HEEBEEJEEBEE_DIRECTORY" ] ; then
        true
    else
        echo "This script needs to create a directory called $HEEBEEJEEBEE_DIRECTORY"
        echo "But that it not possible because something is squatting on that name!"
        error_exit "Refusing to continue without a $HEEBEEJEEBEE_DIRECTORY directory"
    fi
else
    set -x
    mkdir "$HEEBEEJEEBEE_DIRECTORY"
    test -d "$HEEBEEJEEBEE_DIRECTORY"
    set +x
fi

if [ -f "$HOME/.oscrc" ] ; then
    set -x
    cp "$HOME/.oscrc" "$HEEBEEJEEBEE_DIRECTORY"
    set +x
else
    error_exit "Could not find $HOME/.oscrc file... do you have one?"
fi

trap heebeejeebee_cleanup INT TERM EXIT

# process the tarball.sh command line
TEMP=$(getopt -o ho: --long "branch:,help,ibs,outputdir:,project:,pull,obs,repo:" -n 'build.sh' -- "$@")
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -h|--help) usage ;;    # does not return
        --branch) shift ; BRANCH="$1" ; shift ;;
        --ibs)
            OPTION_IBS="$1"
            IBSOBS="$1"
            BUILD_SERVICE="IBS"
            shift
            ;;
        --obs)
            OPTION_OBS="$1"
            IBSOBS="$1"
            BUILD_SERVICE="OBS"
            shift
            ;;
        -o|--outputdir) shift ; OUTPUTDIR="$1" ; shift ;;
        --project) shift ; PROJECT="$1" ; shift ;;
        --pull) OPTION_PULL="$1" ; shift ;;
        --repo) shift ; REPO="$1" ; shift ;;
        --) shift ; break ;;
        *) echo "Internal error" ; false ;;
    esac
done

if [ "$OPTION_IBS" ] && [ "$OPTION_OBS" ] ; then
    echo "ERROR: $OPTION_IBS and $OPTION_OBS options are mutually exclusive"
    error_exit "Provide one or the other, but not both!"
fi

# check that our dependencies are satisfied
assert_command_exists podman
vet_podman_version
if [ "$OPTION_PULL" ] ; then
    podman_pull
    exit 0
fi

echo "=============================================="
echo "BUILD_SERVICE $BUILD_SERVICE"
echo "PROJECT       $PROJECT"
echo "REPO          $REPO"
echo "BRANCH        $BRANCH" 
echo "OUTPUTDIR     $OUTPUTDIR"
echo "=============================================="
echo
echo "Before running the heebeejeebee container, I'm going to take a quick look at your .oscrc file..."

vet_oscrc

echo
echo "The .oscrc file appears to be OK. Running the container now!"
echo

podman run \
    -v "$HEEBEEJEEBEE_DIRECTORY:/root/heebeejeebee" \
    -v "$OUTPUTDIR:/root/output" \
    "$HEEBEEJEEBEE_IMAGE_NAME:latest" \
    "$IBSOBS" \
    "--project" "$PROJECT" \
    "--repo" "$REPO" \
    "--branch" "$BRANCH"
set +x

if [ -d "$OUTPUTDIR/$PROJECT/ceph" ] ; then
    ls -l "$OUTPUTDIR/${PROJECT}/ceph"
    echo "New files in $OUTPUTDIR/${PROJECT}/ceph"
    exit 0
else
    error_exit "failed to generate a new tarball"
fi
