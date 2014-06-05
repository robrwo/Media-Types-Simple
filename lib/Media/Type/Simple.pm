package Media::Type::Simple;

use strict;
use warnings;

use Carp;
use Storable qw( freeze thaw );

use version 0.77; our $VERSION = version->declare('v0.30.1');

# TODO - option to disable reading of MIME types with no associated extensions

{
  # no strict 'refs';

  use Sub::Exporter -setup => {
    exports => [qw( is_type alt_types ext_from_type ext3_from_type
                    is_ext type_from_ext add_type )],
    groups  => {
      default => [qw( is_type alt_types ext_from_type ext3_from_type is_ext type_from_ext) ],
    }
  }
}

=head1 NAME

Media::Type::Simple - MIME Types and their file extensions

=begin readme

=head1 REQUIREMENTS

The following non-core modules are required:

  Sub::Exporter

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
as F<gzip>.  It is defined this way in the default data, but
this does not meet your needs, then you can have it use a system file
(e.g. F</etc/mime.types>) or custom data.

By default, there is a functional interface, although you can also use
an object-oriented inteface.  (Different objects will not share the same
data.)

=for readme stop

=head2 Methods

=cut

my $Default; # Pristine copy of __DATA__
my $Work;    # Working copy of __DATA__

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

sub new {
    my $class = shift;
    my $self  = { types => { }, extens => { }, };

    bless $self, $class;

    if (@_) {
	my $fh = shift;
	return $self->add_types_from_file( $fh );
    }
    else {
	unless (defined $Default) {
	    $Default = $self->add_types_from_file( \*DATA );
	}
	return clone $Default;
    }
}

=begin internal

=item _args

An internal function used to process arguments, based on C<_args> from
the L<self> package.  It also allows one to use it in non-object
oriented mode.

When L</_args> is called for the first time without a reference to the
class instance, it checks to see if C<$Work> is defined, and it is
initialised with L</new> if it is not defined.  This means that
C<$Work> is only initialised when the module is used.

=item self

An internal function used in place of the C<$self> variable.

=item args

An internal function used in place of shifting arguments from stack.

=end internal

=cut

# _args, self and args based on 'self' v0.15

sub _args {
    my $level = 2;
    my @c = ();
    while ( !defined($c[3]) || $c[3] eq '(eval)') {
        @c = do {
            package DB; # Module::Build hates this!
            @DB::args = ();
            caller($level);
        };
        $level++;
    }

    my @args = @DB::args;

    if (ref($args[0]) ne __PACKAGE__) {
	unless (defined $Work) {
	    $Work = __PACKAGE__->new();
	}
	unshift @args, $Work;
    }

    return @args;
}

sub self {
    (_args)[0];
}

sub args {
    my @a = _args;
    return @a[1..$#a];
}


=item add_types_from_file

  $o->add_types_from_file( $filehandle );

Imports types from a file. Called by L</new> when a filehandle is
specified.

=cut

sub add_types_from_file {
    my ($fh) = args;

    while (my $line = <$fh>) {
	$line =~ s/^\s+//;
	$line =~ s/\#.*$//;
	$line =~ s/\s+$//;

	if ($line) {
	    self->add_type(split /\s+/, $line);
	}
    }
    return self;
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
    my ($type) = args;
    my ($cat, $spec)  = split_type($type);
    return self->{types}->{$cat}->{$spec};
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
	my ($type) = args;
	my ($cat, $spec)  = _normalise($type);

	my %alts  = ( );
	my @cases = ( "$cat/$spec", "$cat/x-$spec", "x-$cat/x-$spec",
		      "$cat/vnd.$spec" );

	push @cases, @{ $SPEC_CASES{"$cat/$spec"} },
  	  if ($SPEC_CASES{"$cat/$spec"});

	foreach ( @cases ) {
	    $alts{$_} = 1, if (self->is_type($_));
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
    if (my $exts = self->is_type(args)) {
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
    my @exts = grep( (length($_) <= 3), (ext_from_type(@_)));
    return (wantarray ? @exts : $exts[0]);
}

=item is_ext

  if (is_ext("image/jpeg")) { ... }

  if ($o->is_type("image/jpeg")) { ... }

Returns a true value if the extension is defined in the system.

=begin internal

Currently it returns a reference to a list of types associated
with that extension.  This is for convenience, and may change in future
releases.

=end internal

=cut

sub is_ext {
    my ($ext)  = args;
    if (exists self->{extens}->{$ext}) {
	return self->{extens}->{$ext};
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
    my ($ext)  = args;

    if (my $ts = self->is_ext($ext)) {
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

This is a utlity function for splitting content types.

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
    my ($type, @exts) = args;

    if (@exts || 1) { # TODO - option to ignore types with no extensions

	my ($cat, $spec)  = split_type($type);

	if (!self->{types}->{$cat}->{$spec}) {
	    self->{types}->{$cat}->{$spec} = [ ];
	}
	push @{ self->{types}->{$cat}->{$spec} }, @exts;


	foreach (@exts) {
	    self->{extens}->{$_} = [] unless (exists self->{extens}->{$_});
	    push @{self->{extens}->{$_}}, $type
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

sub clone {
    my $self = shift;
    croak "Expected instance" if (ref($self) ne __PACKAGE__);
    return thaw( freeze $self );
}


=back

=for readme continue

=head1 REVISION HISTORY

For a detailed history see the F<Changes> file included in this distribution.

=head1 SEE ALSO

The L<MIME::Types> module has a similar functionality, but with a more
complex interface.

L<LWP::MediaTypes> will guess the media type from a file extension,
attempting to use the F<~/.media.types> file.

An "official" list of Media Types can be found at
L<http://www.iana.org/assignments/media-types>.

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head2 Suggestions and Bug Reporting

Feedback is always welcome.  Please use the CPAN Request Tracker at
L<http://rt.cpan.org> to submit bug reports.

=head1 ACKNOWLEDGEMENTS

Some of the code comes from L<self> module (by Kang-min Liu).  The data
for the media types is based on the Debian mime-support package,
L<http://packages.debian.org/mime-support>,
although with I<many> changes from the original.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2014 Robert Rothenberg, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;


__DATA__
application/andrew-inset			ez
application/annodex                             anx
application/atom+xml				atom
application/atomcat+xml				atomcat
application/atomserv+xml			atomsrv
application/cals-1840                           cal
application/cap					cap pcap
application/cu-seeme				cu
application/dsptype				tsp
application/envoy                               evy
application/fractals                            fif
application/futuresplash			spl
application/x-gedcom                            ged
application/hta					hta
application/internet-property-stream            acx
application/javascript                          js
application/java-archive			jar
application/java-serialized-object		ser
application/java-vm				class
application/mac-binhex40			hqx
application/mac-compactpro			cpt
application/mathematica				nb
application/mp4                                 mpeg4 mp4
application/msaccess				mdb
application/msword				doc dot
application/mxf                                 mxf
application/octet-stream			bin
application/oda					oda
application/ogg					ogx ogg
application/pdf					pdf
application/x-perfmon                           pma pmc pml pmr pmw
application/pgp-encrypted                       pgp asc
application/pgp-keys				key
application/pgp-signature			pgp asc
application/pics-rules				prf
application/pkcs10                              p10
application/x-pkcs12                            p12 pfx
application/x-pkcs7-certificates  	        p7b spc
application/x-pkcs7-certreqresp                 p7r
application/pkcs7-mime                          p7c p7m
application/pkcs7-signature                     p7s
application/pkix-crl                            crl
application/postscript				ps ai eps
application/rar					rar
application/rdf+xml				rdf
application/rss+xml				rss
application/rtf					rtf
application/set-payment-initiation              setpay
application/set-registration-initiation         setreg
application/sgml                                sgml sml
application/smil				smi smil
application/wordperfect				wpd doc
application/wordperfect5.1			wp5
application/xhtml+xml				xhtml xht
application/xspf+xml                            xspf
application/xml					xml xsl
application/xml-dtd                             dtd
application/zip					zip
application/vnd.cinderella			cdy
application/vnd.google-earth.kml+xml		kml
application/vnd.google-earth.kmz		kmz
application/vnd.lotus-1-2-3                     wks wk1 wk2 wk3 wk4
application/vnd.lotus-approach                  apr apx apt
application/vnd.lotus-freelance                 dgm prz
application/vnd.lotus-notes                     nsf
application/vnd.lotus-organizer                 or2 or3 or4
application/vnd.lotus-screencam
application/vnd.lotus-wordpro                   lwp
application/vnd.mozilla.xul+xml			xul
application/vnd.ms-artgalry
application/vnd.ms-asf
application/vnd.ms-excel			xls xlt xla xlb xlc xlm xlw
application/vnd.ms-lrm
application/vnd.ms-outlook                      msg
application/vnd.ms-pki.seccat			cat
application/vnd.ms-pki.stl			stl
application/vnd.ms-powerpoint			ppt pps pot
application/vnd.ms-project                      mpp
application/vnd.ms-tnef
application/vnd.ms-works                        wcm wdb wks wps
application/winhlp                              hlp
application/vnd.netfpx                          fpx
application/vnd.oasis.opendocument.chart			odc
application/vnd.oasis.opendocument.database			odb
application/vnd.oasis.opendocument.formula			odf
application/vnd.oasis.opendocument.graphics			odg
application/vnd.oasis.opendocument.graphics-template		otg
application/vnd.oasis.opendocument.image			odi
application/vnd.oasis.opendocument.presentation			odp
application/vnd.oasis.opendocument.presentation-template	otp
application/vnd.oasis.opendocument.spreadsheet			ods
application/vnd.oasis.opendocument.spreadsheet-template		ots
application/vnd.oasis.opendocument.text				odt
application/vnd.oasis.opendocument.text-master			odm
application/vnd.oasis.opendocument.text-template		ott
application/vnd.oasis.opendocument.text-web			oth
application/vnd.rim.cod				cod
application/vnd.smaf				mmf
application/vnd.stardivision.calc		sdc
application/vnd.stardivision.chart		sds
application/vnd.stardivision.draw		sda
application/vnd.stardivision.impress		sdd
application/vnd.stardivision.math		sdf
application/vnd.stardivision.writer		sdw
application/vnd.stardivision.writer-global	sgl
application/vnd.sun.xml.calc			sxc
application/vnd.sun.xml.calc.template		stc
application/vnd.sun.xml.draw			sxd
application/vnd.sun.xml.draw.template		std
application/vnd.sun.xml.impress			sxi
application/vnd.sun.xml.impress.template	sti
application/vnd.sun.xml.math			sxm
application/vnd.sun.xml.writer			sxw
application/vnd.sun.xml.writer.global		sxg
application/vnd.sun.xml.writer.template		stw
application/vnd.symbian.install			sis
application/vnd.visio				vsd
application/vnd.wap.wbxml			wbxml
application/vnd.wap.wmlc			wmlc
application/vnd.wap.wmlscriptc			wmlsc
application/x-123				wk
application/x-7z-compressed			7z
application/x-abiword				abw
application/x-apple-diskimage			dmg
application/x-bcpio				bcpio
application/x-bittorrent			torrent
application/x-bzip2                             bz2
application/x-cab				cab
application/x-cbr				cbr
application/x-cbz				cbz
application/x-cdf				cdf
application/x-cdlink				vcd
application/x-chess-pgn				pgn
application/x-compress                          z Z
application/x-compressed                        taz tgz tar.gz
application/x-cpio				cpio
application/x-csh				csh
application/x-debian-package			deb udeb
application/x-director				dcr dir dxr
application/x-dms				dms
application/x-doom				wad
application/x-dvi				dvi
application/x-httpd-eruby			rhtml
application/x-flac				flac
application/x-font				pfa pfb gsf pcf pcf.Z
application/x-freemind				mm
application/x-futuresplash			spl
application/x-gnumeric				gnumeric
application/x-go-sgf				sgf
application/x-graphing-calculator		gcf
application/x-gtar				gtar tgz taz
application/x-gzip                              gz
application/x-hdf				hdf
application/x-httpd-php				phtml pht php
application/x-httpd-php-source			phps
application/x-httpd-php3			php3
application/x-httpd-php3-preprocessed		php3p
application/x-httpd-php4			php4
application/x-ica				ica
application/x-internet-signup			ins isp
application/x-iphone				iii
application/x-iso9660-image			iso
application/x-java-applet                       class
application/x-java-commerce                     jcm
application/x-java-jnlp-file			jnlp
application/x-java-source                       java
application/x-javascript			js
application/x-jmol				jmz
application/x-kchart				chrt
application/x-killustrator			kil
application/x-koan				skp skd skt skm
application/x-kpresenter			kpr kpt
application/x-kspread				ksp
application/x-kword				kwd kwt
application/x-latex				latex
application/x-lha				lha
application/x-lyx				lyx
application/x-lzh				lzh
application/x-lzx				lzx
application/x-maker				frm maker frame fm fb book fbdoc
application/x-mif				mif
application/x-ms-wmd				wmd
application/x-ms-wmz				wmz
application/x-msdos-program			com exe bat dll
application/x-msi				msi
application/x-netcdf				nc cdf
application/x-ns-proxy-autoconfig		pac
application/x-nwc				nwc
application/x-object				o
application/x-oz-application			oza
application/x-pkcs7-certreqresp			p7r
application/x-pkcs7-crl				crl
application/x-python-code			pyc pyo
application/x-quicktimeplayer			qtl
application/x-redhat-package-manager		rpm
application/x-sh				sh
application/x-shar				shar
application/x-shockwave-flash			swf swfl
application/x-stuffit				sit sitx
application/x-sv4cpio				sv4cpio
application/x-sv4crc				sv4crc
application/x-tar				tar
application/x-tcl				tcl
application/x-tex-gf				gf
application/x-tex-pk				pk
application/x-texinfo				texinfo texi
application/x-trash				backup bak old sik ~ %
application/x-troff				t tr roff
application/x-troff-man				man
application/x-troff-me				me
application/x-troff-ms				ms
application/x-ustar				ustar
application/x-wais-source			src
application/x-wingz				wz
application/x-x509-ca-cert			crt
application/x-xcf				xcf
application/x-xfig				fig
application/x-xpinstall				xpi
audio/annodex                                   axa
audio/basic					au snd
audio/midi					mid midi kar
audio/mpeg					mpga mpega mp2 mp3 m4a
audio/mpegurl					m3u
audio/ogg					oga spx ogg
audio/prs.sid					sid
audio/x-aiff					aif aiff aifc
audio/x-gsm					gsm
audio/x-mpegurl					m3u
audio/x-ms-wma					wma
audio/x-ms-wax					wax
audio/x-pn-realaudio				ra rm ram
audio/x-realaudio				ra
audio/x-scpls					pls
audio/x-sd2					sd2
audio/x-wav					wav
chemical/x-alchemy				alc
chemical/x-cache				cac cache
chemical/x-cache-csf				csf
chemical/x-cactvs-binary			cbin cascii ctab
chemical/x-cdx					cdx
chemical/x-cerius				cer
chemical/x-chem3d				c3d
chemical/x-chemdraw				chm
chemical/x-cif					cif
chemical/x-cmdf					cmdf
chemical/x-cml					cml
chemical/x-compass				cpa
chemical/x-crossfire				bsd
chemical/x-csml					csml csm
chemical/x-ctx					ctx
chemical/x-cxf					cxf cef
chemical/x-daylight-smiles			smi
chemical/x-embl-dl-nucleotide			emb embl
chemical/x-galactic-spc				spc
chemical/x-gamess-input				inp gam gamin
chemical/x-gaussian-checkpoint			fch fchk
chemical/x-gaussian-cube			cub
chemical/x-gaussian-input			gau gjc gjf
chemical/x-gaussian-log				gal
chemical/x-gcg8-sequence			gcg
chemical/x-genbank				gen
chemical/x-hin					hin
chemical/x-isostar				istr ist
chemical/x-jcamp-dx				jdx dx
chemical/x-kinemage				kin
chemical/x-macmolecule				mcm
chemical/x-macromodel-input			mmd mmod
chemical/x-mdl-molfile				mol
chemical/x-mdl-rdfile				rd
chemical/x-mdl-rxnfile				rxn
chemical/x-mdl-sdfile				sd sdf
chemical/x-mdl-tgf				tgf
chemical/x-mif					mif
chemical/x-mmcif				mcif
chemical/x-mol2					mol2
chemical/x-molconn-Z				b
chemical/x-mopac-graph				gpt
chemical/x-mopac-input				mop mopcrt mpc dat zmt
chemical/x-mopac-out				moo
chemical/x-mopac-vib				mvb
chemical/x-ncbi-asn1				asn
chemical/x-ncbi-asn1-ascii			prt ent
chemical/x-ncbi-asn1-binary			val aso
chemical/x-ncbi-asn1-spec			asn
chemical/x-pdb					pdb ent
chemical/x-rosdal				ros
chemical/x-swissprot				sw
chemical/x-vamas-iso14976			vms
chemical/x-vmd					vmd
chemical/x-xtel					xtel
chemical/x-xyz					xyz
image/cgm                                       cgm
image/g3fax                                     g3
image/gif					gif
image/ief					ief
image/jpeg					jpeg jpg jpe jfif
image/pipeg					jpeg jpg jpe jfif
image/pjpeg					jpeg jpg jpe jfif
image/pcx					pcx
image/png					png
image/svg+xml					svg svgz
image/tiff					tiff tif
image/vnd.djvu					djvu djv
image/vnd.dwg                                   dwg
image/vnd.dxf                                   dxf
image/vnd.fpx                                   fpx
image/vnd.net-fpx                               fpx
image/vnd.wap.wbmp				wbmp
image/x-cmu-raster				ras
image/x-coreldraw				cdr
image/x-coreldrawpattern			pat
image/x-coreldrawtemplate			cdt
image/x-corelphotopaint				cpt
image/x-icon					ico
image/x-jg					art
image/x-jng					jng
image/x-ms-bmp					bmp
image/x-photoshop				psd
image/x-portable-anymap				pnm
image/x-portable-bitmap				pbm
image/x-portable-graymap			pgm
image/x-portable-pixmap				ppm
image/x-rgb					rgb
image/x-xbitmap					xbm
image/x-xpixmap					xpm
image/x-xwindowdump				xwd
message/rfc822					eml
model/iges					igs iges
model/mesh					msh mesh silo
model/vnd.dwf                                   dwf
model/vrml					wrl vrml
text/calendar					ics icz
text/css					css
text/csv					csv
text/h323					323
text/html					html htm shtml sht
text/iuls					uls
text/mathml					mml
text/plain					asc txt text pot
text/richtext					rtx
text/rtf                                        rtf
text/scriptlet					sct wsc
text/texmacs					tm ts
text/tab-separated-values			tsv
text/vnd.sun.j2me.app-descriptor		jad
text/vnd.wap.wml				wml
text/vnd.wap.wmlscript				wmls
text/x-bibtex					bib
text/x-boo					boo
text/x-c++hdr					h++ hpp hxx hh
text/x-c++src					c++ cpp cxx cc
text/x-chdr					h
text/x-component				htc
text/x-csh					csh
text/x-csrc					c
text/x-dsrc					d
text/x-diff					diff patch
text/x-fortran                                  f f77 f90 for
text/x-haskell					hs
text/x-java					java
text/x-literate-haskell				lhs
text/x-moc					moc
text/x-pascal					p pas
text/x-pcs-gcd					gcd
text/x-perl					pl pm
text/x-prolog                                   pl pro prolog
text/x-python					py
text/x-setext					etx
text/x-sh					sh
text/x-tcl					tcl tk
text/x-tex					tex ltx sty cls
text/x-vcalendar				vcs
text/x-vcard					vcf
video/3gpp					3gp
video/annodex                                   axv
video/dl					dl
video/dv					dif dv
video/fli					fli
video/gl					gl
video/mpeg					mpeg mpg mpe
video/mp4					mp4
video/ogg					ogv
video/quicktime					qt mov
video/vnd.mpegurl				mxu
video/x-la-asf					lsf lsx
video/x-mng					mng
video/x-ms-asf					asf asx
video/x-ms-wm					wm
video/x-ms-wmv					wmv
video/x-ms-wmx					wmx
video/x-ms-wvx					wvx
video/x-msvideo					avi
video/x-sgi-movie				movie
x-conference/x-cooltalk				ice
x-epoc/x-sisx-app				sisx
x-world/x-vrml					vrm vrml wrl
