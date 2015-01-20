package Media::Type::Simple;

use v5.10.1;

use Moo;

use Carp;
use Clone qw/ clone /;
use Types::Standard -types;
use File::Share qw/ dist_file /;
use Class::NonOO v0.3.0;

{
  use version;
  $Media::Type::Simple::VERSION = version->declare('v0.40.0_02');
}

# TODO - option to disable reading of MIME types with no associated extensions

=head1 NAME

Media::Type::Simple - MIME Types and their file extensions

=begin readme

=head1 REQUIREMENTS

The following non-core modules are required:

  Exporter::Lite
  File::Share
  File::ShareDir

=end readme

=head1 SYNOPSIS

  use Media::Type::Simple;

  $type = type_from_ext("jpg");        # returns "image/jpeg"

  $ext  = ext_from_type("text/plain"); # returns "txt"

=head1 DESCRIPTION

This package gives a simple functions for obtaining common file
extensions from media types, and from obtaining media types from
file extensions.

It is also relaxed with respect to having multiple media types
associated with a file extension, or multiple extensions associated
with a media type, and it includes media types for encodings such
as C<gzip>.  It is defined this way in the default data, but
this does not meet your needs, then you can have it use a system file
(e.g. F</etc/mime.types>) or custom data.

By default, there is a functional interface, although you can also use
an object-oriented interface.  (Different objects will not share the
same data.)

=for readme stop

=head2 Methods

=cut

my $Default; # Pristine copy of data_
my $Work;    # Working copy of data

=over

=item new

  $o = Media::Type::Simple->new;

Creates a new object. You may optionally give it a filehandle of a file
with system Media information, e.g.

  open $f, "/etc/mime.types";
  $o =  Media::Type::Simple->new( $f );

=begin internal

When L</new> is called for the first time without a file handle, it
checks to see if the C<$Default> instance is initialised: if it is
not, then it initialises it and returns a L</clone> of C<$Default>.

We operate on clones rather than the original, so that any changes
made, e.g. L</add_type>, will not affect all other instances.

=end internal

=cut

has _types => (
  is          => 'lazy',
  isa         => HashRef,
  default     => sub { {} },
  init_arg    => undef,
);

has _extentions => (
  is       => 'lazy',
  isa      => HashRef,
  default  => sub { {} },
  init_arg => undef,
);

has _types_fh => (
  is      => 'ro', # not lazy
  builder => '_build_types_fh',
);

sub _build_types_fh {
  my $file = dist_file('Media-Type-Simple', 'mime.types');
  open my $fh, '<', $file
    or croak "Unable to open ${file}: $!";
  return $fh;
}

sub BUILDARGS {
  my ($self, @args) = @_;
  if (@args == 1) {
    return { _types_fh => @args };
  }
  return { @args };
}

sub BUILD {
  my ($self, $args) = @_;
  $self->add_types_from_file($self->_types_fh);
}

=item add_types_from_file

  $o->add_types_from_file( $filehandle );

Imports types from a file.

=cut

sub add_types_from_file {
    my ($self, $fh) = @_;

    # TODO: allow a filename as well as filehandle

    while (my $line = <$fh>) {
	$line =~ s/^\s+//;
	$line =~ s/\#.*$//;
	$line =~ s/\s+$//;

	if ($line) {
	    $self->add_type(split /\s+/, $line);
	}
    }
    return $self;
}

=item is_type

  if (is_type("text/plain")) { ... }

  if ($o->is_type("text/plain")) { ... }

Returns a true value if the type is defined in the system.

Note that a true value does not necessarily indicate that the type
has file extensions associated with it.

=begin internal

Currently it returns a reference to a list of extensions associated
with that type.  This is for convenience, and may change in future
releases.

=end internal

=cut

sub is_type {
    my ($self, $type) = @_;
    my ($cat, $spec)  = split_type($type);
    return if ! defined $spec || ! length $spec;
    return $self->_types->{$cat}->{$spec};
}

=item alt_types

  @alts = alt_types("image/jpeg");

  @alts = $o->alt_types("image/jpeg");

Returns alternative or related Media types that are defined in the system
For instance,

  alt_types("model/dwg")

returns the list

  image/vnd.dwg

=begin internal

=item _normalise

=item _add_aliases

=end internal

=cut

{

    # Some known special cases (keys are normalised). Not exhaustive.

    my %SPEC_CASES = (
       "audio/flac"         => [qw( application/flac )],
       "application/cdf"    => [qw( application/netcdf )],
       "application/dms"    => [qw( application/octet-stream )],
       "application/x-java-source" => [qw( text/plain )],
       "application/java-vm" => [qw( application/octet-stream )],
       "application/lha"    => [qw( application/octet-stream )],
       "application/lzh"    => [qw( application/octet-stream )],
       "application/mac-binhex40"  => [qw( application/binhex40 )],
       "application/msdos-program" => [qw( application/octet-stream )],
       "application/ms-pki.seccat" => [qw( application/vnd.ms-pkiseccat )],
       "application/ms-pki.stl"    => [qw( application/vnd.ms-pki.stl )],
       "application/ndtcdf"  => [qw( application/cdf )],
       "application/netfpx" => [qw( image/vnd.fpx image/vnd.net-fpx )],
       "audio/ogg"          => [qw( application/ogg )],
       "image/fpx"          => [qw( application/vnd.netfpx image/vnd.net-fpx )],
       "image/netfpx"       => [qw( application/vnd.netfpx image/vnd.fpx )],
       "text/c++hdr"        => [qw( text/plain )],
       "text/c++src"        => [qw( text/plain )],
       "text/chdr"          => [qw( text/plain )],
       "text/fortran"       => [qw( text/plain )],
    );


  sub _normalise {
      my $type = shift;
      my ($cat, $spec)  = split_type($type);

      # We "normalise" the type

      $cat  =~ s/^x-//;
      $spec =~ s/^(x-|vnd\.)//;

      return ($cat, $spec);
  }

  sub _add_aliases {
      my @aliases = @_;
      foreach my $type (@aliases) {
	  my ($cat, $spec)  = _normalise($type);
	  $SPEC_CASES{"$cat/$spec"} = \@aliases;
      }
  }

    _add_aliases(qw( application/mp4 video/mp4 ));
    _add_aliases(qw( application/json text/json ));
    _add_aliases(qw( application/cals-1840 image/cals-1840 image/cals image/x-cals application/cals ));
    _add_aliases(qw( application/mac-binhex40 application/binhex40 ));
    _add_aliases(qw( application/atom+xml application/atom ));
    _add_aliases(qw( application/fractals image/fif ));
    _add_aliases(qw( model/vnd.dwg image/vnd.dwg image/x-dwg application/acad ));
    _add_aliases(qw( image/vnd.dxf image/x-dxf application/x-dxf application/vnd.dxf ));
    _add_aliases(qw( text/x-c text/csrc ));
    _add_aliases(qw( application/x-helpfile application/x-winhlp ));
    _add_aliases(qw( application/x-tex text/x-tex ));
    _add_aliases(qw( application/rtf text/rtf ));
    _add_aliases(qw( image/jpeg image/pipeg image/pjpeg ));
    _add_aliases(qw( text/javascript text/javascript1.0 text/javascript1.1 text/javascript1.2 text/javascript1.3 text/javascript1.4 text/javascript1.5 text/jscript text/livescript text/x-javascript text/x-ecmascript aplication/ecmascript application/javascript ));


    sub alt_types {
	my ($self, $type) = @_;
	my ($cat, $spec)  = _normalise($type);

	my %alts  = ( );
	my @cases = ( "$cat/$spec", "$cat/x-$spec", "x-$cat/x-$spec",
		      "$cat/vnd.$spec" );

	push @cases, @{ $SPEC_CASES{"$cat/$spec"} },
  	  if ($SPEC_CASES{"$cat/$spec"});

	foreach ( @cases ) {
	    $alts{$_} = 1, if ($self->is_type($_));
	}

	return (sort keys %alts);
    }
}

=item ext_from_type

  $ext  = ext_from_type( $type );

  @exts = ext_from_type( $type );

  $ext  = $o->ext_from_type( $type );

  @exts = $o->ext_from_type( $type );

Returns the file extension(s) associated with the given Media type.
When called in a scalar context, returns the first extension from the
list.

The order of extensions is based on the order that they occur in the
source data (either the default here, or the order added using
L</add_types_from_file> or calls to L</add_type>).

=cut

sub ext_from_type {
  my ($self, $type) = @_;
    if (my $exts = $self->is_type($type)) {
	return (wantarray ? @$exts : $exts->[0]);
    }
    else {
	return;
    }
}

=item ext3_from_type

Like L</ext_from_type>, but only returns file extensions under three
characters long.

=cut

sub ext3_from_type {
  my ($self, $type) = @_;
    my @exts = grep( (length($_) <= 3), ($self->ext_from_type($type)));
    return (wantarray ? @exts : $exts[0]);
}

=item is_ext

  if (is_ext("jpeg")) { ... }

  if ($o->is_ext("jpeg")) { ... }

Returns a true value if the extension is defined in the system.

=begin internal

Currently it returns a reference to a list of types associated
with that extension.  This is for convenience, and may change in future
releases.

=end internal

=cut

sub is_ext {
    my ($self, $ext)  = @_;
    if (exists $self->_extentions->{$ext}) {
	return $self->_extentions->{$ext};
    }
    else {
	return;
    }
}

=item type_from_ext

  $type  = type_from_ext( $extension );

  @types = type_from_ext( $extension );

  $type  = $o->type_from_ext( $extension );

  @types = $o->type_from_ext( $extension );

Returns the Media type(s) associated with the extension.  When called
in a scalar context, returns the first type from the list.

The order of types is based on the order that they occur in the
source data (either the default here, or the order added using
L</add_types_from_file> or calls to L</add_type>).

=cut

sub type_from_ext {
    my ($self, $ext)  = @_;

    if (my $ts = $self->is_ext($ext)) {
	my @types = map { $_ } @$ts;
	return (wantarray ? @types : $types[0]);
    }
    else {
	croak "Unknown extension: $ext";
    }
}

=begin internal

=item split_type

  ($content_type, $subtype) = split_type( $type );

This is a utility function for splitting content types.

=end internal

=cut

sub split_type {
    my $type = shift;
    my ($cat, $spec)  = split /\//,  $type;
    return ($cat, $spec);
}

=item add_type

  $o->add_type( $type, @extensions );

Add a type to the system, with an optional list of extensions.

=cut

sub add_type {
    my ($self, $type, @exts) = @_;

    return unless $type;

    if (@exts || 1) { # TODO - option to ignore types with no extensions

	my ($cat, $spec)  = split_type($type);

        $self->_types->{$cat}{$spec} //= [ ];
        push @{ $self->_types->{$cat}{$spec} }, @exts;

	foreach (@exts) {
	    $self->_extentions->{$_} //= [];
	    push @{$self->_extentions->{$_}}, $type
	}
    }
}

=item clone

  $c = $o->clone;

Returns a clone of a Media::Type::Simple object. This allows you to add
new types via L</add_types_from_file> or L</add_type> without affecting
the original.

This can I<only> be used in the object-oriented interface.

=cut

as_function
  export => [qw/ is_type alt_types ext_from_type ext3_from_type is_ext type_from_ext /];

# TODO:
# our @EXPORT_OK = (@EXPORT, qw/ add_type /);


=back

=for readme continue

=head1 REVISION HISTORY

For a detailed history see the F<Changes> file included in this
distribution.

=head1 SEE ALSO

The L<MIME::Types> module has a similar functionality, but with a more
complex interface.

L<LWP::MediaTypes> will guess the media type from a file extension,
attempting to use the F<~/.media.types> file.

An "official" list of Media Types can be found at
L<http://www.iana.org/assignments/media-types>.

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head2 Contributors

=over

=item Russell Jenkins

=item Martin McGrath

=back

=head2 Acknowledgements

Some of the code comes from L<self> module (by Kang-min Liu).  The data
for the media types is based on the Debian C<mime-support> package,
L<http://packages.debian.org/mime-support>,
although with I<many> changes from the original.

=head2 Suggestions and Bug Reporting

Feedback is always welcome.  Please use the CPAN Request Tracker at
L<http://rt.cpan.org> to submit bug reports.

The git repository for this module is at
L<https://github.com/robrwo/Media-Types-Simple>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2015 Robert Rothenberg, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;


