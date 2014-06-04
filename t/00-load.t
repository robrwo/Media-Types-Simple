#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Media::Type::Simple' );
}

diag( "Testing Media::Type::Simple $Media::Type::Simple::VERSION, Perl $], $^X" );
