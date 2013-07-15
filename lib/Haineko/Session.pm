package Haineko::Session;
use strict;
use warnings;
use Class::Accessor::Lite;
use Haineko::Response;
use Haineko::Address;
use Time::Piece;

my $rwaccessors = [
    'stage',        # (Integer)
    'started',      # (Time::Piece) When it connected
    'response',     # (Haineko::Response) SMTP Reponse
    'addresser',    # (Haineko::Address) Envelope sender
    'recipient',    # (ArreyRef->Haineko::Address) Envelope recipient
];
my $roaccessors = [
    'queueid',      # (String) Queue ID
    'referer',      # (String) HTTP REFERER
    'useragent',    # (String) User agent name
    'remotehost',   # (String) Client IP address
    'remoteport',   # (String) Client port number
];
my $woaccessors = [];
Class::Accessor::Lite->mk_accessors( @$rwaccessors );
Class::Accessor::Lite->mk_ro_accessors( @$roaccessors );


sub new {
    my $class = shift;
    my $argvs = { @_ };
    my $nekos = {
        'stage' => 0,
        'started' => Time::Piece->new,
        'queueid' => $argvs->{'queueid'} || __PACKAGE__->make_queueid,
        'response' => $argvs->{'response'} || Haineko::Response->new,
    };
    map { $nekos->{ $_ } ||= $argvs->{ $_ } || undef } @$roaccessors;

    while(1) {

        my $c = 'Haineko::Address';
        my $r = [];
        my $t = $argvs->{'recipient'} || [];

        map { push @$r, $c->new( 'address' => $_ ) } @$t;
        $nekos->{'recipient'} = $r;

        last unless defined $argvs->{'addresser'};
        $nekos->{'addresser'} = $c->new( 'address' => $argvs->{'addresser'} );

        last;
    }
    return bless $nekos, __PACKAGE__;
}

sub load {
    my $class = shift;
    my $argvs = shift || return undef;
    my $esmtp = {};
    my $rhead = [ qw/dsn code error message command/ ];
    my $nekor = undef;

    return undef unless ref $argvs eq 'HASH';
    return undef unless $argvs->{'smtp.queueid'};

    for my $e ( @$rwaccessors, @$roaccessors ) {

        next unless defined $argvs->{ 'smtp.'.$e };
        next if $e =~ m/(?:response|addresser|recipient)/;
        $esmtp->{ $e } = $argvs->{ 'smtp.'.$e };
    }

    while(1) {
        my $c = 'Haineko::Address';
        my $r = [];
        my $t = $argvs->{'smtp.recipient'} || [];

        map { push @$r, $c->new( 'address' => $_ ) } @$t;
        $esmtp->{'recipient'} = $r;

        last unless defined $argvs->{'smtp.addresser'};
        $esmtp->{'addresser'} = $c->new( 'address' => $argvs->{'smtp.addresser'} );

        last;
    }

    for my $e ( @$rhead ) {
        next unless defined $argvs->{ 'smtp.'.$e };
        $nekor->{ $e } = $argvs->{ 'smtp.'.$e };
    }

    $nekor->{'message'} = [];
    $esmtp->{'message'} = [];
    $esmtp->{'response'} = Haineko::Response->new( %$nekor );

    return bless $esmtp, __PACKAGE__;
}

sub make_queueid {
    my $class = shift;
    my $size1 = 16;
    my $time1 = new Time::Piece;
    my $chars = [ '0'..'9', 'A'..'Z', 'a'..'x' ];
    my $idstr = q();
    my $queue = {
        'Y' => $chars->[ $time1->_year % 60 ],
        'M' => $chars->[ $time1->_mon ],
        'D' => $chars->[ $time1->mday ],
        'h' => $chars->[ $time1->hour ],
        'm' => $chars->[ $time1->min ],
        's' => $chars->[ $time1->sec ],
        'q' => $chars->[ int rand(60) ],
        'p' => sprintf( "%05d", $$ ),
    };

    $idstr .= $queue->{ $_ } for ( qw/Y M D h m s q p/ );

    while(1) {
        $idstr .= $chars->[ int rand( scalar( @$chars ) ) ];
        last if length $idstr == $size1;
    }
    return $idstr; 
}

sub done {
    my $class = shift;
    my $argvs = shift || return 0;
    my $value = {
        'ehlo' => ( 1 << 0 ),
        'auth' => ( 1 << 1 ),
        'mail' => ( 1 << 2 ),
        'rcpt' => ( 1 << 3 ),
        'data' => ( 1 << 4 ),
        'quit' => ( 1 << 5 ),
    };
    return $value->{ $argvs } || 0;
}

sub ehlo { 
    my $self = shift; 
    my $argv = shift || 0;
    my $ehlo = __PACKAGE__->done('ehlo');
    $self->{'stage'} = $ehlo if $argv;
    return $self->{'stage'} & $ehlo ? 1 : 0;
}

sub auth {
    my $self = shift;
    my $argv = shift || 0;
    my $auth = __PACKAGE__->done('auth');
    $self->{'stage'} |= $auth if $argv;
    return $self->{'stage'} & $auth ? 1 : 0;
}

sub mail {
    my $self = shift;
    my $argv = shift || 0;
    my $mail = __PACKAGE__->done('mail');
    $self->{'stage'} |= $mail if $argv;
    return $self->{'stage'} & $mail ? 1 : 0;
}

sub rcpt {
    my $self = shift;
    my $argv = shift || 0;
    my $rcpt = __PACKAGE__->done('rcpt');
    $self->{'stage'} |= $rcpt if $argv;
    return $self->{'stage'} & $rcpt ? 1 : 0;
}

sub rset {
    my $self = shift;
    $self->{'stage'} = __PACKAGE__->done('ehlo');
    return 1;
}

sub quit {
    my $self = shift;
    $self->{'stage'} = 0;
    return 1;
}

sub r {
    my $self = shift;
    my $smtp = shift || return 0;
    my $type = shift || return 0;
    my $logs = shift || [];
    my $head = [ qw/dsn code error message command/ ];
    my $mesg = Haineko::Response->r( $smtp, $type, $logs );

    return 0 unless defined $mesg;
    $self->{'response'} = $mesg;
    return 1;
}

sub damn {
    my $self = shift;
    my $smtp = {};

    for my $e ( @$rwaccessors, @$roaccessors ) {

        next if $e =~ m/(?:response|addresser|recipient)/;
        $smtp->{ 'smtp.'.$e } = $self->{ $e };
    }

    while(1) {
        last unless defined $self->{'addresser'};
        last unless ref $self->{'addresser'};
        last unless ref $self->{'addresser'} eq 'Haineko::Address';

        $smtp->{'smtp.addresser'} = $self->{'addresser'}->address;
        last;
    }

    while(1) {
        last unless defined $self->{'recipient'};
        last unless ref $self->{'recipient'} eq 'ARRAY';

        for my $e ( @{ $self->{'recipient'} } ) {

            next unless ref $e eq 'Haineko::Address';
            push @{ $smtp->{'smtp.recipient'} }, $e->address;
        }
        last;
    }

    while(1) {
        last unless defined $self->{'response'};
        last unless ref $self->{'response'} eq 'Haineko::Response';

        $smtp->{'smtp.response'} = $self->{'response'}->damn;
        last;
    }
    return $smtp;
}

1;
__END__

=encoding utf8

=head1 NAME

Haineko::Session - HTTP to SMTP Session class

=head1 DESCRIPTION

Haineko::Session manages a connection from HTTP and SMTP session on Haineko server.

=head1 SYNOPSIS

    use Haineko::Session;
    my $v = { 
        'useragent' => 'Mozilla',
        'remotehost' => '127.0.0.1',
        'remoteport' => 62401,
    };
    my $e = Haineko::Session->new( %$v );
    $e->addresser( 'kijitora@example.jp' );
    $e->recipient( [ 'neko@example.org' ] );

    print $e->queueid;      # r64CvGQ21769QslMmPPuD2jC
    print $e->started;      # Thu Jul  4 18:00:00 2013 (Time::Piece object)
    print $e->addresser->user;  # kijitora (Haineko::Address object)
    print $e->recipient->[0]->host; # example.org (Haineko::Address object)

=head1 CLASS METHODS

=head2 B<new( I<%arguments> )>

new() is a constructor of Haineko::Session

    my $e = Haineko::Session->new( 
            'useragent' => $self->req->headers->user_agent,
            'remotehost' => $self->req->headers->header('REMOTE_HOST'),
            'remoteport' => $self->req->headers->header('REMOTE_PORT'),
            'addresser' => 'kijitora@example.jp',
            'recipient' => [ 'neko@example.org', 'cat@example.com' ],
    );

=head2 B<load( I<Hash reference> )>

load() is also a constructor of Haineko::Session. 

    my $v = {
        'smtp.queueid' => 'r64CvGQ21769QslMmPPuD2jC',
        'smtp.addresser' => 'kijitora@example.jp',
    };
    my $e = Haineko::Session->load( %$v );

    print $e->queueid;      # r64CvGQ21769QslMmPPuD2jC
    print $e->addresser->address;   # kijitora@example.jp

=head2 B<make_queueid>

make_queueid() generate a queue id string.
    print Haineko::Session->make_queueid;   # r64IHFV22109f8KATxdNDSj7
    print Haineko::Session->make_queueid;   # r64IHJP22111Q9PCwpWX1Pd0
    print Haineko::Session->make_queueid;   # r64IHV622112od227ioJMxhh



=head1 INSTANCE METHODS

=head2 B<r( I<SMTP command>, I<Error type> [,I<Message>] )>

r() sets Haineko::Response object from a SMTP Command and an error type.

    my $e = Haineko::Session->new( ... );
    print $e->response->dsn;    # undef

    $e->r( 'RCPT', 'rejected' );
    print $e->response->dsn;    # 5.7.1
    print $e->response->code;   # 553

=head2 B<damn>

damn() returns instance data as a hash reference for Mojolicious session.

    warn Data::Dumper::Dumper $e;
    $VAR1 = {
          'smtp.referer' => undef,
          'smtp.queueid' => 'r64IQ9X22396oA0bjQZIU7rn',
          'smtp.addresser' => 'kijitora@example.jp',
          'smtp.response' => {
                       'dsn' => undef,
                       'error' => undef,
                       'message' => undef,
                       'command' => undef,
                       'code' => undef
                     },
          'smtp.remotehost' => '127.0.0.1',
          'smtp.useragent' => 'CLI',
          'smtp.started' => bless( [
                         9,
                         26,
                         18,
                         4,
                         6,
                         '113',
                         4,
                         184,
                         0,
                         1372929969,
                         1
                       ], 'Time::Piece' ),
          'smtp.stage' => 4,
          'smtp.remoteport' => 1024
        };

=head1 REPOSITORY

https://github.com/azumakuniyuki/haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
