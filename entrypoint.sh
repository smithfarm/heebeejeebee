#!/bin/bash

export LANG=en_US.UTF-8
SCRIPTNAME="$(basename "${0}")"
BRANCH="master"
IOSC="osc --no-keyring --no-gnome-keyring -A https://api.suse.de"
OOSC="osc --no-keyring --no-gnome-keyring -A https://api.opensuse.org"
OSC="$OOSC"
PROJECT="filesystems:ceph:master:upstream"
REPO="https://github.com/ceph/ceph.git"

function usage {
    set +x
    echo "$SCRIPTNAME - generate ceph tarballs using Dockerfiles"
    echo
    echo "Options:"
    echo "    --branch        Branch to pass to checkin.sh (defaults to \"master\")"
    echo "    --help          Display this usage message"
    echo "    --ibs           Use IBS"
    echo "    --obs           Use OBS (the default)"
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

function error_exit {
    local message="$1"
    echo "($SCRIPTNAME) ERROR: $message"
    exit 1
}

set -e
TEMP=$(getopt -o h --long "help,branch:,ibs,obs,project:,repo:" -n 'entrypoint.sh' -- "$@")
set +e
eval set -- "$TEMP"

set -x
while true ; do
    echo "$*"
    case "$1" in
        -h|--help)
            usage
            ;;            # does not return
        --branch)
            BRANCH="$2"
            shift 2
            continue
            ;;
        --ibs)
            OSC="$IOSC"
            shift
            continue
            ;;
        --obs)
            shift
            continue
            ;;
        --project)
            PROJECT="$2"
            shift 2
            continue
            ;;
        --repo)
            REPO="$2"
            shift 2
            continue
            ;;
        --)
            shift
            break
            ;;
        *)
            error_exit "(internal) Failed to process command-line arguments!"
            ;;    # does not return
    esac
done

# expand repo shortcuts
# FIXME: use bash regex instead of perl here (?)
if [ "$(perl -e '"'"$REPO"'" =~ m/(^\w+$)/; print "$1\n";')" ] ; then
    REPO="https://github.com/$REPO/ceph.git"
elif [ "$(perl -e '"'"$REPO"'" =~ m/(^\w+\/\w+$)/; print "$1\n";')" ] ; then
    REPO="https://github.com/$REPO.git"
fi

# make sure we are in /root and not somewhere silly like /
set -ex
test -d /root
cd /root

# expect to find our .oscrc all ready to go
test -d /root/heebeejeebee
test -f /root/heebeejeebee/.oscrc
cp /root/heebeejeebee/.oscrc /root
chmod 600 /root/.oscrc
file /root/.oscrc

$OSC --version

# build tarball
rm -rf "$PROJECT/ceph"
$OSC co "$PROJECT" ceph
pushd "$PROJECT/ceph"
bash checkin.sh --repo "$REPO" --branch "$BRANCH"
popd

# copy the tarball, etc. from /root/$PROJECT/ceph to /root/output/$PROJECT/ceph
# for consumption outside the container
rm -rf "output/$PROJECT"
mkdir "output/$PROJECT"
cp -a "$PROJECT/ceph" "output/$PROJECT"
