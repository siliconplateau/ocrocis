#!/usr/bin/env perl

use strict;
use warnings;

use v5.14;

use Pod::Usage;

use FindBin;
use lib "$FindBin::Bin";

use ocrocis_tools qw(
JP2_EXTENSION_PATTERN IMAGE_EXTENSION_PATTERN
ocropus info nag call error help

init loc check_prereqs_for

globbed unglobbed make_dir
);

my ($pdf, @pages, $convert, $ocropus_nlbin);
my $num_cpus = 1;

sub convert_pdf {
    my ( $pdf, @pages ) = @_;

    info "Converting $pdf to page images at ". loc 'book';

    nag "No pages numbers specified, therefore converting all pages"
        unless @pages;

    my $pdf_range = @pages ? '['.unglobbed(@pages).']' : '';

    ocropus $convert, "convert",
        "'$pdf$pdf_range'",
        loc 'book', "/%04d.png";
}

sub convert_jp2 {
    @_ or return;

    info "Converting JPEG 2000 images to PNG";

    for (@_) {
        /^(.+)\.[^\.]+$/;
        call "convert $_ $1.png";
    }
}

sub binarize_images {
    error "Could not find any valid image files in ". loc 'book'
        unless @_;

    info "Binarizing images in ". loc 'book';

    ocropus $ocropus_nlbin, "ocropus-nlbin",
        "--parallel", $num_cpus,
        "--output",   loc('book'),
        @_;

    info "Initialized project at " . loc 'home';
}

{ # MAIN
    init(
        options => {
            "cpus=i"          => \$num_cpus,
            "pdf=s"           => \$pdf,
            "convert=s"       => \$convert,
            "ocropus-nlbin=s" => \$ocropus_nlbin,
        },
        ARGV => \@pages,
    )
        and ( not @pages or @pages and $pdf )
            or help;

    if ($pdf) {
        make_dir loc 'book';
        check_prereqs_for 'book_imgs';
        convert_pdf( $pdf, @pages );
    }
    else {
        info "No PDf file specified, looking for images in " . loc 'book';

        my $JP2_EXTENSION_PATTERN = JP2_EXTENSION_PATTERN;
        convert_jp2(
            grep { /\.(?|$JP2_EXTENSION_PATTERN)$/i }
            globbed loc 'book', "/*"
        );

        check_prereqs_for 'book_bins';
    }

    my $IMAGE_EXTENSION_PATTERN = IMAGE_EXTENSION_PATTERN;
    binarize_images(
        grep { /(?<!\.bin|\.nrm)\.(?|$IMAGE_EXTENSION_PATTERN)$/i }
        globbed loc 'book', "/*"
    );
}

__END__

=head1 NAME

ocrocis convert - convert a PDF file or a set of images to binary PNG images

=head1 SYNOPSIS

ocrocis convert [OPTIONS] [PAGE-NUMBER ...]

=head1 DESCRIPTION

This command converts a source into binary images. The source can either be a PDF file or a set of images within the project home directory.

Created/updated in the project home:

=over 4

=item - book/[binary page images]

=back

=head2 Options

=over 4

=item B<--pdf> PATH

path to PDF file, optionally with B<PAGE-NUMBERS> (default: use images in the project home directory)

=item B<PAGE-NUMBERS>

numbers of pages to convert (default: all pages), requires B<--pdf>

=back

=head2 Ocropy options to pass through

=over 4

=item B<--convert> STRING

pass-through options for I<imagemagick convert> (default: '')

=item B<--ocropus-nlbin> STRING

pass-through options for I<ocropus-gpageseq> (default: '')

=back

=head2 General options

=over 4

=item B<--cpus> NUMBER, B<-c> NUMBER

number of CPUs for multithreading (default: 1)

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

    ocrocis convert
    ocrocis convert --verbose --cpus 4
    ocrocis convert --verbose --cpus 4 --pdf demo.pdf
    ocrocis convert --verbose --cpus 4 --pdf demo.pdf {50..56}

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
