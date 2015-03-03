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

dir_basename dirnames unique pattern globbed
);

my (@page_images, $ocropus_gpageseg);
my $num_cpus = 1;

sub burst_images {
    my $images_pattern = shift;

    my @image_dirs = unique dirnames globbed $images_pattern;

    info "Bursting binary images in: " . join ", ", @image_dirs;

    ocropus $ocropus_gpageseg, "ocropus-gpageseg",
        "--parallel", $num_cpus,
        "--nocheck",
        $images_pattern;

    my @line_dirs = sort grep { -d } globbed map { "$_/* " } @image_dirs;

    info "Created line images in " . join(", ", @line_dirs);
}

{ # MAIN
    init(
        options => {
            "cpus=i"             => \$num_cpus,
            "ocropus-gpageseg=s" => \$ocropus_gpageseg,
        },
        ARGV => \@page_images,
    )
        or help;

    my $pattern;

    if (@page_images) {
        my @missing_files = grep { not -e $_ } @page_images;

        error "You specified individual files to burst, but some do not exist: " . join ', ', @missing_files
            if @missing_files;

        $pattern = join ' ', @page_images;
    }
    else {
        check_prereqs_for 'book_lines';
        $pattern = pattern 'book_bins';
    }

    burst_images( $pattern );
}

__END__

=head1 NAME

ocrocis burst - segment each binary page image into a directory of line images

=head1 SYNOPSIS

ocrocis burst [OPTIONS] [IMAGE ...]

=head1 DESCRIPTION

Created/updated in the project home:

=over 4

=item - book/[page directories]

=back

=head2 Options

=over 4

=item B<--cpus> NUMBER, B<-c> NUMBER

number of CPUs for multithreading (default: 1)

=back

=head2 Ocropy options to pass through

=over 4

=item B<--ocropus-gpageseg> STRING

pass-through options for I<ocropus-gpageseg> (default: '')

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

    ocrocis burst
    ocrocis burst --verbose --cpus 4 --ocropus-gpageseg "--minscale 10"
    ocrocis burst --verbose --cpus 4 --ocropus-gpageseg "--minscale 10" myproject/book/*.bin.png

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

