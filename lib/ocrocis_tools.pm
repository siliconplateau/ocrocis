package ocrocis_tools;

use strict;
use warnings;

use v5.14;

use Exporter;
use Pod::Usage;
use Getopt::Long qw(:config auto_abbrev);
use File::Basename;
use Term::ANSIColor;
# use Data::Printer;

our $VERSION   = 1.00;
our @ISA       = qw( Exporter );
our @EXPORT_OK = qw(
JP2_EXTENSION_PATTERN IMAGE_EXTENSION_PATTERN

init
check_prereqs_for

ocropus info nag call error help

unique not_in

globbed unglobbed
loc pattern

dir_basename dirnames
make_dir make_parent

get_pageline_pattern get_pagegt_pattern

extract_charset load_charset write_charset

find_pagefiles find_pagelines find_pagegts
find_models find_latest_model
find_remaining_annotation_pages

hardlink_pagefiles
filter_on_sibling_gt
normalize_inplace
);

sub JP2_EXTENSION_PATTERN { join '|', qw(
jp2 j2k jpf jpx
) }

sub IMAGE_EXTENSION_PATTERN { join '|', qw(
png PNG
jpeg JPEG jpg JPG
tif TIF tiff TIFF
) }

sub EXT {{
    gt    => '.gt.txt',
    bin   => '.bin.png',
    img   => '.png',
    model => '.pyrnn.gz'
}->{(shift)}}

my %P;
my $loc;
my $prereqs;

my $debug = 0;
my $verbose = 0;

sub nag(@);
sub info(@);
sub call(@);
sub error(@);
sub ocropus(@);

sub loc(@);
sub pad(@);
sub init(%);
sub clean($@);
sub unique(@);
sub imbue($$@);
sub pattern($);
sub globbed(@);
sub dirnames(@);
sub unglobbed(@);
sub reoffset($$$);
sub getarrayif($@);
sub dir_basename(@);
sub init_locations($$);
sub get_locations($;&);

sub make_dir(@);
sub make_parent(@);

sub get_name(@);
sub get_parentbase(@);
sub get_extension(@);
sub get_extension_pattern(@);
# sub get_iteration_dir($;&);

sub find_models($);
sub find_latest_model(%);

sub find_pagegts(@);
sub find_pagefiles(@);
sub find_pagelines(@);
sub pagefile_pattern(@);
sub get_pagegt_pattern(@);
sub get_pagefile_pattern(@);
sub get_pageline_pattern(@);

sub previous_iteration();
sub next_iteration();
sub current_iteration();

sub filter_on_sibling_gt(@);
sub hardlink_pagefiles($@);
sub find_remaining_annotation_pages();

sub normalize_inplace(@);
sub extract_charset(@);
sub load_charset();
sub write_charset(@);
sub not_in($$);

sub check_prereqs($);

sub imbue($$@) {
    my $fh = shift;
    say $fh colored( join(' ', @_[1..$#_]), $_[0] );
    1
}

sub info(@) {
    imbue \*STDERR, 'green', '[OCROCIS]', '[INFO]', '[iteration '.current_iteration().']', @_
        if $verbose or $debug;
    1
}

sub nag(@) {
    imbue \*STDERR, 'yellow', '[OCROCIS]', '[WARN]', '[iteration '.current_iteration().']', @_
        if $verbose or $debug;
    1
}

sub error(@) {
    imbue \*STDERR, 'red', '[OCROCIS]', '[ERROR]', @_
        and exit 1;
}

sub call(@) {
    my $cmd = join ' ', grep { $_ } @_;

    imbue \*STDERR, 'cyan', '[OCROCIS]', '[CALL]', $cmd
        if $debug;

    0 == system $cmd
        or error "System command failed: $cmd";
}

sub help {
    pod2usage({ -exitval => 1, -verbose => 2, -output => \*STDOUT })
}

sub ocropus(@) {
    my $ocropus_opts = shift;
    splice @_, 1, 0,
        map { s/^\s+|\s+$//g; $_ } ($ocropus_opts)
            if $ocropus_opts;

    my $cmd = join ' ', ( grep { $_ } @_ ), '2>&1';

    imbue \*STDOUT, 'blue', '[OCROCIS]', '[OCROPUS]', $cmd
        if $verbose or $debug;

    0 == system $cmd
        or error "Ocropus command failed: $cmd";
}

sub init(%) {
    my $help;
    my $home = '.';
    my %params = @_;

    my $got_options = GetOptions(
        "home=s"   => \$home,
        "help|?"   => \$help,
        "debug!"   => \$debug,
        "verbose!" => \$verbose,
        %{$params{options}}
    );

    @{ $params{ARGV} } = @ARGV
        if exists $params{ARGV} and ref $params{ARGV} eq ref [];

    init_locations $home,
        ( exists $params{iteration} and $params{iteration} );

    $got_options and not $help
}

sub init_locations($$) {
    my $dir_home = shift;

    $loc = {
        home    => $dir_home,

        book    => "$dir_home/book",
        charset => "$dir_home/book/charset.txt",
        # tmp     => "$dir_home/book/.tmp",

        train => "$dir_home/training",
        test  => "$dir_home/test",
    };

    my $iteration = get_iteration(shift);

    %$loc = ( %$loc,
        iteration    => "$dir_home/iterations/$iteration",
        annotation   => "$dir_home/iterations/$iteration/annotation",
        html         => "$dir_home/iterations/$iteration/Correction.html",
        models       => "$dir_home/iterations/$iteration/models",
        model_prefix => "$dir_home/iterations/$iteration/models/model",
    );

    init_prereqs();
}

sub get_iteration {
    (
        map {{
            none     => sub { "00" },
            previous => \&previous_iteration,
            current  => \&current_iteration,
            next     => \&next_iteration
        }->{$_}()}
        (
            (shift) or 'none'
        )
    )[0]
}

sub previous_iteration() {
    sprintf '%02d',-1 + ( current_iteration or 1 )
}

sub next_iteration() {
    sprintf '%02d', 1 + ( current_iteration or 0 )
}

sub current_iteration() {
    my $dir = loc('home')."/iterations";

    return "00"
        unless -e $dir;

    my @dirs =
        grep { -d }
        map  { "$dir/$_" }
        split /\s+/, `ls $dir`;

    return "00"
        unless @dirs;

    shift [
        sort { $b <=> $a }
        dir_basename
        @dirs
    ]
}

sub init_prereqs {
    init_patterns();

    $prereqs = {
        $P{test} => [ # Test
            $P{annotation_files},
        ],
        $P{annotation_files} => [ # Test
            $P{annotation_gts},
        ],
        $P{annotation_gts} => [ # Test
            $P{annotation_lines},
        ],
        $P{train} => [ # Train
            $P{html}
        ],
        $P{html} => [ # Next
            $P{annotation_lines},
        ],
        $P{annotation_lines} => [ # Next
            $P{book_lines},
        ],
        $P{book_lines} => [ # Burst
            $P{book_imgs},
        ],
        $P{book_bins} => [ # Convert
            $P{book},
        ],
        $P{book_imgs} => [ # Convert
            $P{book}
        ],
        $P{book} => [ 1 ]
    };
}

sub init_patterns {
    %P = (
        annotation_files => loc('annotation').'/*/*',
        annotation_lines => loc('annotation').'/*/*'.EXT('bin'),
        annotation_gts   => loc('annotation').'/*/*'.EXT('gt'),
        book_lines       => loc('book').'/*/*'.EXT('bin'),
        book_bins        => loc('book').'/*'.EXT('bin'),
        book_imgs        => loc('book').'/*'.EXT('img'),
        train            => loc('train'),
        test             => loc('test'),
        html             => loc('html'),
        book             => loc('book'),
    );
}

sub pattern($) {
    $P{(shift)}
}

sub loc(@) {
    $loc->{(shift)} . join '', @_
}

sub globbed(@) {
    my $path = join '', @_;
    $path =~ s/^\s*(.+?)\s*$/$1/;
    <"$path">
}

sub reoffset($$$) {
    my ($dir_from, $dir_to, $offset) = @_;
    for (<"$dir_from/*">) {
        /(\d+)([\w\.]*)$/ or die;
        my $id2 = sprintf '%04d', ($1 + $offset - 1);
        call "mv $_ $dir_to/$id2$2";
    }
}

sub find_models($) {
    my $dir = shift;
    my @models = globbed "$dir/*.pyrnn.gz";

    error "Could not find any models in $dir"
        unless @models;

    getarrayif wantarray,
        @models
}

# sub get_iteration_dir($;&) {
#     my ($get_iteration) = @_;
#
#     join '/',
#         loc('home'),
#         'iterations',
#         (
#             $get_iteration and $get_iteration->()
#                 or "00"
#         )
# }

sub find_latest_model(%) {
    my $iteration = get_iteration {@_}->{iteration};

    my $dir_models = join '/',
        loc('home'),
        'iterations',
        $iteration,
        "models";

    info("Starting from scratch, since there are no previous models") and return undef
        unless -d $dir_models;

    my $model = shift [
        sort { $b cmp $a }
        find_models $dir_models
    ];

    if ($model) {
        info "Using latest model from iteration $iteration: $model";
    }
    else {
        info "Could not find any model in iteration $iteration";
    }

    $model
}

sub make_dir(@) {
    my @nodirs = unique grep { not -d $_ } @_;
    return unless @nodirs;
    call 'mkdir -p', map { s/\/[^\/]+\.[^\/]+$/\//g; $_ } @nodirs
}

sub make_parent(@) {
    make_dir get_parent(@_);
}

sub get_parent(@) {
    getarrayif wantarray,
        map { [ /^(.+?)\/[^\/]+$/ ]->[0] } @_
}

sub dirnames(@) {
    getarrayif wantarray,
        map { dirname $_ } @_
}

sub getarrayif($@) {
    (shift) ? @_ : shift
}

sub get_parentbase(@) {
    getarrayif wantarray,
        map { /([^\/]+\/[^\/]+)$/; $1 or $_ } @_
}

sub unglobbed(@) {
    join ',', sort @_
}

sub pad(@) {
    map { sprintf '%04d', $_ } @_
}

sub replace_extension($@) {
    my $extension = shift;
    getarrayif wantarray,
        map { /^(.+\/[^\/\.]+)\.[^\/]+$/; $1.$extension } @_
}

sub filter_on_sibling_gt(@) {
    my @files_with_gt =
        map  { @$_ }
        grep { -f $_->[1] }
        map  { [ $_,replace_extension(EXT('gt'),$_) ] } @_;

    error "There are no ground truths for the selected pages. Did you annotate them in the annotation HTML?"
        unless @files_with_gt;

    getarrayif wantarray,
        @files_with_gt
}

sub get_name(@) {
    getarrayif wantarray,
        map { [ /([^\/\.]+)[^\/]+$/ ]->[0] } @_
}

sub pagefile_pattern(@) {
    my ($pattern, $dir, @pages) = @_;
    my $pages = (
           @pages == 0 and '*'
        or @pages == 1 and unglobbed(pad(shift(@pages)))
        or                 '{'.unglobbed(pad @pages).'}'
    );
    "$dir/$pages/*$pattern"
}

sub get_pagefile_pattern(@) {
    find_pagefiles @_;
    pagefile_pattern '', @_
}

sub get_pageline_pattern(@) {
    find_pagelines @_;
    pagefile_pattern EXT('bin'), @_
}

sub get_pagegt_pattern(@) {
    find_pagegts @_;
    pagefile_pattern EXT('gt'), @_
}

sub find_pagefiles(@) {
    my $pattern = pagefile_pattern '', @_;
    my @files = globbed $pattern;

    error "No page files found in " . $_[0]
        unless @files;

    @files
}

sub find_pagelines(@) {
    my $pattern = pagefile_pattern EXT('bin'), @_;
    my @files = globbed $pattern;

    error "No page lines found in " . $_[0]
        unless @files;

    @files
}

sub find_pagegts(@) {
    my $pattern = pagefile_pattern EXT('gt'), @_;
    my @files = globbed $pattern;

    error "No page ground truths found in " . $pattern
        unless @files;

    @files
}

sub dir_basename(@) {
    getarrayif wantarray,
        map  { basename $_ }
        grep { -d $_ } @_
}

sub find_remaining_annotation_pages() {
    # my $iteration = get_iteration 'current';
    #
    # my $dir_iteration = join '/',
    #     loc('home'),
    #     'iterations',
    #     $iteration;

    my %annotation_pages = map { $_ => 1 } dir_basename globbed loc 'annotation', "/*";
    my %training_pages   = map { $_ => 1 } dir_basename globbed loc 'train', "/*";

    for (keys %training_pages) {
        $annotation_pages{$_}++ if exists $annotation_pages{$_};
    }

    my @remaining_pages = map { pad $_ }
        sort { $a <=> $b }
        grep { $annotation_pages{$_} == 1 }
        keys %annotation_pages;

    info "Using remaining annotation pages as test set: " . join ', ', @remaining_pages;

    @remaining_pages
}

sub unique(@) {
    sort keys %{ { map { $_ => 1 } @_ } }
}

sub clean($@) {
    my $pattern = shift;
    for (unique @_) {
        if (-d $_) {
            my @files = globbed "$_/*$pattern";
            call 'rm -rf', @files if @files;
        }
        elsif (-f $_) {
            call 'rm -f', $_;
        }
    }
}

sub get_extension(@) {
    getarrayif wantarray,
    map { /^.+\/[^\/\.]+(\.[^\/]+)$/; $1 } @_
}

sub get_extension_pattern(@) {
    '{' . join(',', unique get_extension @_) . '}'
}

sub hardlink_pagefiles($@) {
    my ($dir_to, @pagefiles) = @_;

    my @links =
        map { [
            $_,
            "$dir_to/" . get_parentbase $_
        ] }
        @pagefiles;

    my @destination_parents =
        get_parent
        map { $_->[1] }
        @links;
    make_dir
        @destination_parents;

    clean
        get_extension_pattern(@pagefiles),
        @destination_parents;

    my $cmd = build_consolidation_cmd();
    info "Consolidation command: $cmd";

    call "$cmd $_->[0] $_->[1]"
        for @links;
}

sub build_consolidation_cmd {
    my $uname = (
           `cat ~/host_uname 2>/dev/null`
        or `uname`
    );
    chomp $uname;

    ( $uname eq 'Linux' and 'ln -f' or 'cp' );
}

sub normalize_inplace(@) {
    use Unicode::Normalize;
    for (@_) {
        open my $in, '<:utf8', $_ or die $!;
        my $c = NFKC do { local $/; <$in> };
        close $in;

        open my $out, '>:utf8', $_ or die $!;
        print $out NFKC($c);
        close $out;
    }
}

sub extract_charset(@) {
    sort { $a cmp $b }
    unique
    grep {
        /[^[:space:]]/
    }
    map {
        open my $in, '<:utf8', $_ or error "Could not find ground truths at $_";
        my $c = NFKC do { local $/; <$in> };

        close $in;

        split //, $c
    } @_
}

sub load_charset() {
    open my $fh, '<:utf8', loc('charset') or return '';
    my $c = NFKC do { local $/; <$fh> };
    close $fh;
    split //, $c
}

sub write_charset(@) {
    open my $fh, '>:utf8', loc('charset') or die $!;
    print $fh join '', @_;
    close $fh;
}

sub not_in($$) {
    my %set_a = map { $_ => 1 } @{(shift)};
    my %set_b = map { $_ => 1 } @{(shift)};

    sort { $a cmp $b }
    grep { not exists $set_b{$_} }
    keys %set_a
}

sub check_prereqs_for($) {
    has_prereqs($P{(shift)});
}

sub has_prereqs {
    my $target = shift;

    error "Unknown target: $target"
        unless exists $prereqs->{$target};

    for (@{$prereqs->{$target}}) {
        return 1
            if $_ eq 1;

        my @files = <"$_">;
        error "Missing prerequisite files $_ for target $target. Did you follow all steps in order?"
            unless @files;

        has_prereqs($_);
    }

    1
}

1

__END__

=head1 AUTHOR

    David Kaumanns (2015)
    I<kaumanns@cis.lmu.de>

    Center for Information and Language Processing
    University of Munich

=head1 COPYRIGHT

Ocrocis (2015) is licensed under Apache License, Version 2.0, see L<http://www.apache.org/licenses/LICENSE-2.0>

=cut
