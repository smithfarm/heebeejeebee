#!/bin/bash

SCRIPTNAME=$(basename ${0})
OUTPUTDIR="/home/$(logname)"
test -d "$OUTPUTDIR" || OUTPUTDIR="$HOME"

runtime=docker
runtime_opts=""
if which podman >&/dev/null; then
  runtime=podman
  runtime_opts="--userns=keep-id"
fi

function usage {
    echo "$SCRIPTNAME - generate ceph tarballs using Dockerfiles"
    echo
    echo "Options:"
    echo "    --branch        Branch to pass to checkin.sh (defaults to \"master\")"
    echo "    --help          Display this usage message"
    echo "    --ibs           Use IBS"
    echo "    --obs           Use OBS (the default)"
    echo "    --outputdir     Directory under which to create the target osc checkout (defaults to \"$OUTPUTDIR\")"
    echo "    --package       Project package (defaults to \"ceph\")"
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


find_oscrc() {

  if [[ -e "./oscrc" ]]; then
    echo "$(realpath ./oscrc)"
  elif [[ -e "${HOME}/.oscrc" ]]; then
    echo "$(realpath ${HOME}/.oscrc)"
  elif [[ -e "${HOME}/.config/osc/oscrc" ]]; then
    echo "$(realpath ${HOME}/.config/osc/oscrc)"
  else
    echo ""
  fi
}


TEMP=$(getopt -o ho: \
  --long "branch:,help,ibs,outputdir:,project:,obs,repo:,package:" \
  -n 'build.sh' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

BRANCH="master"
BUILD_SERVICE="OBS"
IBS=""
OBS="--obs"
BS_OPT=""
PACKAGE="ceph"
PROJECT="filesystems:ceph:octopus:upstream"
REPO="https://github.com/ceph/ceph.git"
while true ; do
    case "$1" in
        -h|--help) usage ;;    # does not return
        --branch) shift ; BRANCH="$1" ; shift ;;
        --ibs) IBS="$1" ; OBS="" ; BS_OPT="$1" ; BUILD_SERVICE="IBS" ; shift ;;
        --obs) OBS="$1" ; IBS="" ; BS_OPT="$1" ; BUILD_SERVICE="OBS" ; shift ;;
        -o|--outputdir) shift ; OUTPUTDIR="$1" ; shift ;;
        --package) shift ; PACKAGE="$1" ; shift ;;
        --project) shift ; PROJECT="$1" ; shift ;;
        --repo) shift ; REPO="$1" ; shift ;;
        --) shift ; break ;;
        *) echo "Internal error" ; false ;;
    esac
done

oscrc=$(find_oscrc)
if [[ -z "${oscrc}" ]]; then
  echo "error: unable to find a viable osc config file"
  exit 1
fi

echo "=============================================="
echo "BUILD_SERVICE $BUILD_SERVICE"
echo "PACKAGE       $PACKAGE"
echo "PROJECT       $PROJECT"
echo "REPO          $REPO"
echo "BRANCH        $BRANCH" 
echo "OUTPUTDIR     $OUTPUTDIR"
echo "OSC CONFIG    ${oscrc}"
echo "=============================================="

run_image="obs"
if [[ -n "$IBS" ]]; then
  run_image="ibs"
fi

set -x
rm -rf $OUTPUTDIR/$PROJECT/$PACKAGE
$runtime run $runtime_opts \
    -v "$OUTPUTDIR:/builder/output" \
    -v "${oscrc}:/builder/.oscrc" \
    -v "$(pwd)/bin:/builder/bin" \
    hbjb-run:${run_image} \
    "$BS_OPT" --project "$PROJECT" --repo "$REPO" --branch "$BRANCH" \
    --package $PACKAGE

ls -l $OUTPUTDIR/${PROJECT}/$PACKAGE
set +x

if [ -d $OUTPUTDIR/$PROJECT/$PACKAGE ] ; then
    echo "New content in $OUTPUTDIR/${PROJECT}/ceph"
    exit 0
else
    echo "tarball.sh: failed to generate a new tarball"
    exit 1
fi
