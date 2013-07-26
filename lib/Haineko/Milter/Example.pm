package Haineko::Milter::Example;
use strict;
use warnings;
use parent 'Haineko::Milter';

sub conn {
    my $class = shift;
    my $nekor = shift || return 1;  # Haineko::Response object
    my $argvs = [ @_ ];

    my $remotehost = $argvs->[0] // q();
    my $remoteaddr = $argvs->[1] // q();

    if( $remotehost eq 'localhost.localdomain' ) {

        $nekor->error(1);
        $nekor->message( [ 'Error message here' ] );

    } elsif( $remoteaddr eq '255.255.255.255' ) {
        $nekor->error(1);
        $nekor->message( [ 'Broadcast address' ] );

        # Or Check REMOTE_ADDR with DNSBL...
    }

    return $nekor->error ? 0 : 1;
}

sub ehlo {
    my $class = shift;
    my $nekor = shift || return 1;  # Haineko::Response object
    my $argvs = shift // q();       # Hostname or IP address

    if( $argvs =~ m/[.]local\z/ ) {

        $nekor->code(521);
        $nekor->error(1);
        $nekor->message( [ 'Invalid domain ".local"' ] );
    }

    return $nekor->error ? 0 : 1;
}

sub mail {
    my $class = shift;
    my $nekor = shift || return 1;  # Haineko::Response object
    my $argvs = shift // q();       # Envelope sender address

    my $invalidtld = [ 'local', 'test', 'invalid' ];
    my $spamsender = [ 'spammer@example.com', 'spammer@example.net' ];

    if( grep { $argvs =~ m/[.]$_\z/ } @$invalidtld ) {
        $nekor->error(1);
        $nekor->message( [ 'sender domain does not exist' ] );

    } elsif( grep { $argvs eq $_ } @$spamsender ) {
        $nekor->error(1);
        $nekor->message( [ 'spammer is not allowed to send'] );
    }

    return $nekor->error ? 0 : 1;
}

sub rcpt {
    my $class = shift;
    my $nekor = shift || return 1;  # Haineko::Response object
    my $argvs = shift // [];        # Envelope recipient addresses
    my $bccto = 'always-bcc@example.jp';

    push @$argvs, $bccto unless grep { $bccto eq $_ } @$argvs;
    return $nekor->error ? 0 : 1;
}

sub head {
    my $class = shift;
    my $nekor = shift || return 1;  # Haineko::Response object
    my $argvs = shift // {};        # Headers(HashRef)

    if( exists $argvs->{'subject'} && $argvs->{'subject'} =~ /spam/i ) {

        $nekor->error(1);
        $nekor->dsn('5.7.1');
        $nekor->message( [ 'DO NOT SEND spam' ] );
    }

    return $nekor->error ? 0 : 1;
}

sub body {
    my $class = shift;
    my $nekor = shift || return 1;  # Haineko::Response object
    my $argvs = shift // {};        # Body(ScalarRef)

    if( $$argvs =~ m{https?://} ) {

        $nekor->error(1);
        $nekor->message( [ 'Not allowed to send an email including URL' ] );
    }

    return $nekor->error ? 0 : 1;
}


1;
__END__
