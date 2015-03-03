#!/bin/bash

#USER=docker

#[[ -z $UID ]] && echo "User: $UID" && exit 1

# useradd --uid "$UID" "$USER" -p '*'
# adduser docker sudo 2>&1 >/dev/null

if [ "$HOST_UNAME" == "Linux" ]; then
    sudo -u docker /opt/ocrocis/ocrocis.sh "$@"
    # - just sudo creates files that belong to root
    # - no sudo does not permit file creation at all
elif [ "$HOST_UNAME" == "Darwin" ]; then
    sudo /opt/ocrocis/ocrocis.sh "$@"
    # - no sudo does not permit file creation at all
fi
