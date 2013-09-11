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
