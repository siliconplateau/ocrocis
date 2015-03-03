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

unique not_in make_parent
extract_charset load_charset write_charset
find_pagelines find_pagegts
hardlink_pagefiles filter_on_sibling_gt normalize_inplace find_latest_model get_pageline_pattern
);

my ($model, $ntrain, $savefreq, @pages, $ocropus_gtedit, $ocropus_rtrain);

sub extract_gts {
    info "Extracting ground truths from " . loc('html');

    ocropus $ocropus_gtedit, "ocropus-gtedit",
        "extract",
        "-O",
        loc('html');
}

sub set_model {
    my @annotation_gts = find_pagegts loc('annotation');

    normalize_inplace @annotation_gts;

    my @current_charset = extract_charset @annotation_gts;

    my @charset = load_charset;
    info "Character set of whole book so far:\n\t" . join '', @charset;

    my @new_chars = not_in \@current_charset, \@charset;

    if (@new_chars) {
        info "Found new characters in current annotation set:\n\t" . join '', @new_chars;
        my @new_charset = unique (@charset, @current_charset);

        info "Updating character set with\n\t" . join '', @new_charset;
        write_charset @new_charset;

        info "Discarding previous models and starting from scratch";
        $model = undef;
    }
    else {
        info "No new characters were introduced by the annotation set";

        if ($model and not -f $model) {
            error "Could not find model: $model";
        }
        elsif (not $model) {
            $model = find_latest_model iteration => 'previous'
        }

        info "-> Reusing model from $model"
            if $model;
    }
}

sub consolidate {
    info "Adding new links from training set to annotation set";

    hardlink_pagefiles loc('train'),
        filter_on_sibling_gt
            find_pagelines loc('annotation'),
                @pages;
}

sub train {
    my $pageline_pattern = get_pageline_pattern loc 'train';

    make_parent loc 'model_prefix';

    info "Running training on training set at " . loc 'train';

    my $opt_model = ( $model and -f $model and "--load $model" or '' );
    # my $opt_codec = ( -f loc('charset') and "--codec ".loc('charset') or '' );
    error "Could not find character set in " . loc('charset')
        unless -f loc('charset');

    ocropus $ocropus_rtrain, "ocropus-rtrain",
        "--ntrain",   $ntrain,
        "--savefreq", $savefreq,
        $opt_model,
        "--codec " . loc('charset'),
        "--output",   loc('model_prefix'),
        $pageline_pattern;

    info "Finished training new models at " . loc 'model_prefix';
}

{ # MAIN
    init(
        options => {
            "model=s"          => \$model,
            "ntrain=i"         => \$ntrain,
            "savefreq=i"       => \$savefreq,
            "ocropus-gtedit=s" => \$ocropus_gtedit,
            "ocropus-rtrain=s" => \$ocropus_rtrain,
        },
        ARGV      => \@pages,
        iteration => 'current'
    )
        and $ntrain and $savefreq and @pages
            or help;

    check_prereqs_for 'train';
    extract_gts();
    set_model();
    consolidate();
    train();
}

__END__

=head1 NAME

ocrocis train - prepare and run training

=head1 SYNOPSIS

ocrocis train [OPTIONS] --ntrain NUMBER --savefreq NUMBER PAGE-NUMBER...

=head1 DESCRIPTION

This command extracts the ground truth from the annotation HTML, expands the global training set and trains new models.

Created/updated in the project home:

=over 4

=item - training/[page directories]

=back

=head2 Options

=over 4

=item B<PAGE-NUMBERS>

numbers of pages with which to expand the training set (required)

=item B<--ntrain> NUMBER

number of training steps (required)

=item B<--savefreq> NUMBER

number of training steps after which a model should be saved (required, must be lower than ntrain)

=item B<--model> FILE-PATH

model to use as starting point (default: load last model from previous iteration, if it exists)

=back

=head2 Ocropy options to pass through

=over 4

=item B<--ocropus-gtedit> STRING

pass-through options for I<ocropus-gtedit> (default: '')

=item B<--ocropus-rtrain> STRING

pass-through options for I<ocropus-rtrain> (default: '')

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

    ocrocis train --ntrain 10 --savefreq 5 {1..2}
    ocrocis train --ntrain 20 --savefreq 5 --model iterations/01/models/model-00000005.pyrnn.gz --verbose {1..2}

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
