#!/bin/bash

basedir=$(dirname $0)

if [ "`uname`" == "Darwin" ] && [ "`boot2docker status`" != "running" ]; then
    echo "Starting boot2docker on Darwin"
    boot2docker start
    $(boot2docker shellinit)
fi

if [[ "$@" =~ "../" || "$@" =~ " /" ]]; then
    echo "[OCROCIS] [INFO] You seem refer to a file above this directory. Due to the restrictions of Docker containers, you have no access to files above the current directory (since is mounted inside the sandboxed container)."
    echo "Please copy the file to this directory (or to one below it) and access it from there."
    exit 1
fi

if [[ -z "$@" ]]; then
    docker run --interactive --tty --volume="`pwd`":"/opt/work" --volume="$basedir/../lib":"/opt/ocrocis" --workdir="/opt/work" --env HOST_UNAME="`uname`" --user docker ocrocis ?
else
    docker run --interactive --tty --volume="`pwd`":"/opt/work" --volume="$basedir/../lib":"/opt/ocrocis" --workdir="/opt/work" --env HOST_UNAME="`uname`" --user docker ocrocis "$@"
fi

# AUTHOR

    # David Kaumanns (2015)
    # kaumanns@cis.lmu.de

    # Center for Information and Language Processing
    # University of Munich

# COPYRIGHT

    # Ocrocis (2015) is licensed under Apache License, Version 2.0, see L<http://www.apache.org/licenses/LICENSE-2.0>
