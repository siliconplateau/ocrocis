#!/bin/bash
help="Usage: ocrocis [convert|burst|next|train|predict] --help"

[[ -z "$@" || "$@" == "?" ]] && echo "$help" && exit 1
basedir=$(dirname $0)
cmd=$1; shift

# For perl-only installation
basedir=${basedir/%bin/lib}

executable="$basedir/ocrocis_${cmd}.pl"

[[ ! -f "$executable" ]] && echo "$help" && exit 1

"$executable" "$@"

# AUTHOR

    # David Kaumanns (2015)
    # kaumanns@cis.lmu.de

    # Center for Information and Language Processing
    # University of Munich

# COPYRIGHT

    # Ocrocis (2015) is licensed under Apache License, Version 2.0, see L<http://www.apache.org/licenses/LICENSE-2.0>
