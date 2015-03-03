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

find_pagelines find_models find_latest_model find_remaining_annotation_pages
hardlink_pagefiles filter_on_sibling_gt get_pageline_pattern get_pagegt_pattern
);

my ($model, $dir, $use_book, $use_train, $use_errors, @pages, $ocropus_gtedit, $ocropus_rpred, $ocropus_errs);
my $num_cpus = 1;

sub collect_models {
    not $model and return ( find_latest_model iteration => 'current' )
        or -d $model and return ( find_models $model )
        or return ( $model )
}

sub prepare_repository {
    error "Not a valid page repository: $dir"
        unless not $dir or -d $dir;

    unless ($dir) {
        if ($use_book) {
            $dir = loc 'book';
        }
        elsif ($use_train) {
            check_prereqs_for 'annotation_lines';
            $dir = loc 'train';
        }
        else {
            check_prereqs_for 'test';

            extract_gts();
            consolidate();

            $dir = loc 'test';
        }
    }
}

sub extract_gts {
    info "Extracting ground truths from " . loc('html');

    ocropus $ocropus_gtedit, "ocropus-gtedit",
        "extract",
        "-O",
        loc('html');
}

sub consolidate {
    @pages = find_remaining_annotation_pages
        unless @pages;

    error "Could not find any remaining annotation pages in " . loc 'annotation'
        unless @pages;

    info "Expanding test set at " . loc('test');

    hardlink_pagefiles loc('test'),
        filter_on_sibling_gt
            find_pagelines loc('annotation'),
                @pages;
}

sub test {
    my $models = shift;
    my $dir = shift;

    my $pageline_pattern = get_pageline_pattern $dir, @pages;

    my $pagegt_pattern = (
        $use_errors and get_pagegt_pattern $dir, @pages
    );

    info "Found " . scalar(@$models) . " models in " . loc 'models'
        if @$models > 1;

    info "Running evaluations" . ( $use_errors and ' with error evaluations' or '' );

    for (@$models) {
        info "Using model $_";
        run_predictions($_, $pageline_pattern);
        run_errors($pagegt_pattern)
            if $use_errors;
    }
}

sub run_predictions {
    my ($model, $pattern) = @_;

    info "Running predictions of model $model";

    ocropus $ocropus_rpred, "ocropus-rpred",
        "--parallel", $num_cpus,
        "--nocheck",
        "--model",    $model,
        $pattern;
}

sub run_errors {
    my $pattern = shift;

    info "Running evaluation";

    ocropus $ocropus_errs, "ocropus-errs",
        "--parallel", $num_cpus,
        $pattern;
}

{ # MAIN
    init(
        options => {
            "cpus=i"           => \$num_cpus,
            "model=s"          => \$model,
            "dir=s"            => \$dir,
            "book!"            => \$use_book,
            "train!"           => \$use_train,
            "errors!"          => \$use_errors,
            "ocropus-gtedit=s" => \$ocropus_gtedit,
            "ocropus-rpred=s"  => \$ocropus_rpred,
            "ocropus-errs=s"   => \$ocropus_errs,
        },
        ARGV      => \@pages,
        iteration => 'current'
    )
        and ( not ( $use_book or $use_train ) or ( $use_book xor $use_train ) )
            or help;

    my @models = collect_models();

    prepare_repository();

    test( \@models, $dir );

    info "Finished evaluation of page repository at $dir";
}

__END__

=head1 NAME

ocrocis predict - prepare and run tests

=head1 SYNOPSIS

ocrocis predict [OPTIONS] [PAGE-NUMBER...]

=head1 DESCRIPTION

This command expands the global test set and tests models as specified. Each test creates predictions and evaluations based on one model or a set of models.

Created/updated in the project home:

=over 4

=item - test/[page directories]

=back

=head2 Options

=over 4

=item B<PAGE-NUMBERS>

numbers of pages with which to expand the test set (default: use all pages from the current iteration annotation set that have not been used in training)

=item B<--model> FILE-PATH|DIR-PATH

test one model from a file or each model in a directory (default: test last model from current iteration)

=item B<--book>

switch to run the test on the unannotated book repository (instead of the annotated global test set), producing only predictions, no evaluations

=back

=head2 Ocropy options to pass through

=over 4

=item B<--ocropus-gtedit> STRING

pass-through options for I<ocropus-gtedit> (default: '')

=item B<--ocropus-rpred> STRING

pass-through options for I<ocropus-rpred> (default: '')

=item B<--ocropus-errs> STRING

pass-through options for I<ocropus-errs> (default: '')

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

    ocrocis predict
    ocrocis predict --verbose 3
    ocrocis predict --verbose --model iterations/01/models
    ocrocis predict --verbose --model iterations/01/models 3
    ocrocis predict --verbose --model iterations/01/models/model-00000005.pyrnn.gz
    ocrocis predict --verbose --model iterations/01/models/model-00000005.pyrnn.gz 3

    ocrocis predict --book
    ocrocis predict --book {1..3}
    ocrocis predict --book --verbose --model some-model-from-another-project.pyrnn.gz
    ocrocis predict --book --verbose --model iterations/02/models
    ocrocis predict --book --verbose --model iterations/02/models/model-00000010.pyrnn.gz
    ocrocis predict --book --verbose --model iterations/02/models/model-00000010.pyrnn.gz {1..3}

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
