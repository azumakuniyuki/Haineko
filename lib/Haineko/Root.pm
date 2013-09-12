package Haineko::Root;
use strict;
use warnings;

sub index {
    my $class = shift;
    my $httpd = shift;

    return $httpd->res->text( 200, $httpd->name );
}

sub neko {
    my $class = shift;
    my $httpd = shift;

    return $httpd->res->text( 200, 'Nyaaaaa' );
}

1;
__END__
=encoding utf-8

=head1 NAME

Haineko::Root - Controller except /submit

=head1 DESCRIPTION

    Haineko::Root is a controller except url /submit.

=head1 SYNOPSYS

=head2 URL

    http://127.0.0.1:2794/

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
