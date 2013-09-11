package Haineko::HTTPD::Response;
use parent 'Plack::Response';
use strict;
use warnings;

sub mime {
    my $class = shift;
    my $ctype = shift || 'plain';
    my $types = {
        'json'  => 'application/json',
        'html'  => 'text/html; charset=utf-8',
        'plain' => 'text/plain; charset=utf-8',
    };

    $ctype = 'plain' if $ctype eq 'text';
    $ctype = 'plain' unless exists $types->{ $ctype };
    return $types->{ $ctype };
}

sub text {
    my $self = shift;
    my $code = shift || 200;
    my $text = shift;

    $self->code( $code );
    return $self->_res( $text, 'text' );
}

sub json {
    my $self = shift;
    my $code = shift || 200;
    my $data = shift;   # (Ref->[HASH|ARRAY]) or JSON as a string
    my $json = q();

    require Haineko::JSON;
    $json = ref $data ? Haineko::JSON->dumpjson( $data ) : $data;
    $self->code( $code );
    return $self->_res( $json, 'json' );
}

sub _res {
    my $self = shift;
    my $text = shift || q();
    my $type = shift || 'json';
    my $head = [
        'Content-Type' => Haineko::HTTPD::Response->mime( $type ),
        'Content-Length' => length $text,
        'X-Content-Type-Options' => 'nosniff',
    ];

    $self->code(200) unless $self->code;
    $self->headers( $head );
    $self->body( $text );
    return $self;
}

1;
__END__
