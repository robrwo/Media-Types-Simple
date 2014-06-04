
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Media::Type::Simple',
    AUTHOR              => 'Robert Rothenberg <rrwo@cpan.org>',
    VERSION_FROM        => 'lib/Media/Type/Simple.pm',
    ABSTRACT_FROM       => 'lib/Media/Type/Simple.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Carp'       => 0,
        'Storable'   => 0,
        'Sub::Exporter' => 0,
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Media-Type-Simple-*' },
);
