#!/bin/bash

runtime=docker
if which podman ; then
  runtime=podman
fi

if ! which $runtime ; then
  echo "can't find binary for $runtime in path"
  exit 1
fi


usage() {
  cat << EOF
usage: $0 [base | run] [--ibs]

options:
  base       builds only base images
  run        builds only run image
  --ibs      whatever is built, also builds for IBS.
  -h|--help  this message.

Note that building images without specifying '--ibs' means that only OBS
images will be built. This default is for the benefit of those without access
to SUSE's internal network/vpn.
EOF

}

do_base=true
do_run=true
do_ibs=false


while [[ $# -gt 0 ]]; do
  case $1 in
    base) do_base=true ; do_run=false ;;
    run) do_base=false; do_run=true ;;
    --ibs) do_ibs=true ;;
    --help|-h) usage ; exit 0 ;;
    *) usage ; exit 1 ;;
  esac
  shift 1
done

if $do_base ; then

  $runtime build \
    --no-cache \
    --tag hbjb-base:obs \
    --file ./images/base/Dockerfile-base . || exit 1

  if $do_ibs ; then
    $runtime build \
      --no-cache \
      --tag hbjb-base:ibs \
      --file ./images/base/Dockerfile-base-ibs . || exit 1
  fi
fi

if $do_run ; then
  $runtime build \
    --no-cache \
    --tag hbjb-run:obs \
    --file ./images/run/Dockerfile-run-obs . || exit 1

  if $do_ibs ; then
    $runtime build \
      --no-cache \
      --tag hbjb-run:ibs \
      --file ./images/run/Dockerfile-run-ibs . || exit 1
  fi

fi

