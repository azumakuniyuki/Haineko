package Haineko::HTTPD::Router;
use strict;
use warnings;
use parent 'Router::Simple';

sub conn {
    my $self = shift;
    return $self->connect( @_ );
}
1;
