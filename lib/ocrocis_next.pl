#!/usr/bin/env perl

use strict;
use warnings;

use v5.14;

use Pod::Usage;
use Getopt::Long qw(:config auto_abbrev);

use FindBin;
use lib "$FindBin::Bin";

use ocrocis_tools qw(
ocropus info nag call error help

init loc check_prereqs_for

get_pageline_pattern hardlink_pagefiles find_pagefiles
);

my (@pages, $ocropus_gtedit);

sub create_html {
    my $pageline_pattern = get_pageline_pattern loc 'annotation';

    info "Creating annotation HTML at " . loc 'html';

    ocropus $ocropus_gtedit, "ocropus-gtedit",
        "html",
        '-H35',
        "-o", loc('html'),
        $pageline_pattern;

    info "Initialized next iteration at " . loc 'iteration'
}

sub consolidate {
    info "Consolidating next annotation set at " . loc 'annotation';

    hardlink_pagefiles loc('annotation'),
        find_pagefiles loc('book'),
            @_;
}

{ # MAIN
    init(
        options => {
            "ocropus-gtedit=s" => \$ocropus_gtedit,
        },
        ARGV      => \@pages,
        iteration => 'next',
    )
        and @pages
            or help;

    check_prereqs_for 'annotation_lines';

    consolidate(@pages);

    create_html();
}

__END__

=head1 NAME

ocrocis next - initialize the next project iteration

=head1 SYNOPSIS

ocrocis next [OPTIONS] PAGE-NUMBER...

=head1 DESCRIPTION

This command consolidates a set of pages from the book repository as new annotation set and creates the annotation HTML.

If you want to undo this step, simply remove the respective iteration subdirectory.

Created/updated in the project home:

=over 4

=item - iterations/[next iteration number]/annotation/[page directories]

=item - iterations/[next iteration number]/Correction.html

=back

=head2 Options

=over 4

=item B<PAGE-NUMBERS>

numbers of pages for the annotation set (required)

=back

=head2 Ocropy options to pass through

=over 4

=item B<--ocropus-gtedit> STRING

pass-through options for I<ocropus-gtedit> (default: '')

=back

=head2 General options

=over 4

=item B<--home> PATH

project home directory (default: .)

=item B<--verbose, -v>

switch for output of I<Ocrocis> commands (default: off)

=item B<--debug, -d>

switch for output of I<Ocrocis> commands and system commands (default: off)

=item B<--help>

print help page and exit

=back

=head1 EXAMPLES

    ocrocis next {1..3}
    ocrocis next --verbose {1..3}

=head1 SEE ALSO

    ocrocis [convert|burst|next|train|test]

=head1 AUTHOR

    David Kaumanns (2015)
    I<kaumanns@cis.lmu.de>

    Center for Information and Language Processing
    University of Munich

=head1 COPYRIGHT

Ocrocis (2015) is licensed under Apache License, Version 2.0, see L<http://www.apache.org/licenses/LICENSE-2.0>

=cut
