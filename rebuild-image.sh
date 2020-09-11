#!/bin/bash

BASE=""
RUN=""

if [[ "$*" =~ "base" ]] ; then
    echo "Will rebuild base and run container images"
    BASE="yes"
    RUN="yes"
elif [[ "$*" =~ "run" ]] ; then
    echo "Will rebuild run container image"
    RUN="yes"
else
    echo "Will rebuild both base and run container images"
    BASE="yes"
    RUN="yes"
fi

if [ "$BASE" ] ; then
    docker build \
        --no-cache \
        --tag hbjb-base \
        --file ./Dockerfile-base \
        .
fi

if [ "$RUN" ] ; then
    docker build \
        --no-cache \
        --tag hbjb-run \
        --file ./Dockerfile-run \
        .
fi
