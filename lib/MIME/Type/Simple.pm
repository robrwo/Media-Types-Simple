=head1 NAME

MIME::Type::Simple - MIME Media Types and their file extensions

=head1 DESCRIPTION

MIME::Type::Simple has been renamed to L<Media::Type::Simple>.

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Rothenberg, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

package MIME::Type::Simple;

our $VERSION = '0.02';

BEGIN {
    die __PACKAGE__." has been renamed to Media::Type::Simple.";
}

1;
