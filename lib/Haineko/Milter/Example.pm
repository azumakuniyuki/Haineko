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

=encoding utf8

=head1 NAME

Haineko::Milter::Example - Haineko milter for Example

=head1 DESCRIPTION

Example Haineko::Milter class.

=head1 SYNOPSIS

    use Haineko::Milter;
    Haineko::Milter->import( [ 'Example' ]);

=head1 IMPLEMENT MILTER METHODS (Override Haineko::Milter)

Each method is called from /submit at each phase of SMTP session. If you want to
reject the smtp connection, set required values into Haineko::Response object and
return 0 or undef as a return value of each method. However you want to only rewrite
contents or passed your contents filter, return 1 or true as a return value.


=head2 B<conn( I<Haineko::Response>, I<REMOTE_HOST>, I<REMOTE_ADDR> )>

conn() method is for checking a client hostname and client IP address.

=head3 Arguments

=head4 B<Haineko::Response> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
Default SMTP status codes is 421 in this method.

=head4 B<REMOTE_HOST>

The host name of the message sender, as picked from HTTP REMOTE_HOST variable.

=head4 B<REMOTE_ADDR>

The host address, as picked from HTTP REMOTE_ADDR variable.


=head2 B<ehlo( I<Haineko::Response>, I<HELO_HOST> )>

ehlo() method is for checking a hostname passed as an argument of EHLO.

=head3 Arguments

=head4 B<Haineko::Response> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 521 in this method.

=head4 B<HELO_HOST>

Value defined in "ehlo" field in HTTP-POSTed JSON data, which should be the 
domain name of the sending host or IP address enclosed square brackets.


=head2 B<mail( I<Haineko::Response>, I<ENVELOPE_SENDER> )>

mail() method is for checking an envelope sender address.

=head3 Arguments

=head4 B<Haineko::Response> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 501, dsn is 5.1.8
in this method.

=head4 B<ENVELOPE_SENDER>

Value defined in "mail" field in HTTP-POSTed JSON data, which should be the 
valid email address.


=head2 B<rcpt( I<Haineko::Response>, I< [ ENVELOPE_RECIPIENTS ] > )>

rcpt() method is for checking envelope recipient addresses. Envelope recipient
addresses are passwd as an array reference.

=head3 Arguments

=head4 B<Haineko::Response> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 553, dsn is 5.7.1
in this method.

=head4 B<ENVELOPE_RECIPIENTS>

Values defined in "rcpt" field in HTTP-POSTed JSON data, which should be the 
valid email address.


=head2 B<head( I<Haineko::Response>, I< { EMAIL_HEADER } > )>

head() method is for checking email header. Email header is passwd as an hash
reference.

=head3 Arguments

=head4 B<Haineko::Response> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 554, dsn is 5.7.1
in this method.

=head4 B<EMAIL_HEADER>

Values defined in "header" field in HTTP-POSTed JSON data.


=head2 B<body( I<Haineko::Response>, I< \EMAIL_BODY > )>

head() method is for checking email body. Email body is passwd as an scalar
reference.

=head3 Arguments

=head4 B<Haineko::Response> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 554, dsn is 5.6.0
in this method.

=head4 B<EMAIL_HEADER>

Value defined in "body" field in HTTP-POSTed JSON data.


=head1 SEE ALSO

https://www.milter.org/developers/api/

=head1 REPOSITORY

https://github.com/azumakuniyuki/Haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut
