package Haineko::SMTPD::Milter::Example;
use strict;
use warnings;
use parent 'Haineko::SMTPD::Milter';

sub conn {
    # @Description  Milter code at SMTP connection
    # @Param <obj>  (Haineko::SMTPD::Response) Object
    # @Return       (Integer) 1 = Allow, 0 = Reject
    my $class = shift;
    my $nekor = shift || return 1;
    my $argvs = [ @_ ];

    my $remotehost = $argvs->[0] // '';
    my $remoteaddr = $argvs->[1] // '';

    if( $remotehost eq 'localhost.localdomain' ) {
        # Reject ``localhost.localdomain''
        $nekor->error(1);
        $nekor->message( [ 'Error message here' ] );

    } elsif( $remoteaddr eq '255.255.255.255' ) {
        # Reject ``255.255.255.255''
        $nekor->error(1);
        $nekor->message( [ 'Broadcast address' ] );

        # Or Check REMOTE_ADDR with DNSBL...
    }

    return $nekor->error ? 0 : 1;
}

sub ehlo {
    # @Description  Milter code at EHLO
    # @Param <obj>  (Haineko::SMTPD::Response) Object
    # @Param <str>  (String) Hostname or IP address
    # @Return       (Integer) 1 = Allow, 0 = Reject
    my $class = shift;
    my $nekor = shift || return 1;
    my $argvs = shift // '';

    if( $argvs =~ m/[.]local\z/ ) {
        # Reject ``EHLO *.local''
        $nekor->code(521);
        $nekor->error(1);
        $nekor->message( [ 'Invalid domain ".local"' ] );
    }

    return $nekor->error ? 0 : 1;
}

sub mail {
    # @Description  Milter code at MAIL FROM
    # @Param <obj>  (Haineko::SMTPD::Response) Object
    # @Param <str>  (String) Envelope sender address
    # @Return       (Integer) 1 = Allow, 0 = Reject
    my $class = shift;
    my $nekor = shift || return 1;
    my $argvs = shift // '';

    my @invalidtld = ( 'local', 'test', 'invalid');
    my @spamsender = ( 'spammer@example.com', 'spammer@example.net' );

    if( grep { $argvs =~ m/[.]$_\z/ } @invalidtld ) {
        # Reject by domain part of envelope sender address
        $nekor->error(1);
        $nekor->message( [ 'sender domain does not exist' ] );

    } elsif( grep { $argvs eq $_ } @spamsender ) {
        # Not allowed address
        $nekor->error(1);
        $nekor->message( [ 'spammer is not allowed to send'] );
    }

    return $nekor->error ? 0 : 1;
}

sub rcpt {
    # @Description  Milter code at RCPT TO
    # @Param <obj>  (Haineko::SMTPD::Response) Object
    # @Param <list> (Ref->Array) Envelope recipient addresses
    # @Return       (Integer) 1 = Allow, 0 = Reject
    my $class = shift;
    my $nekor = shift || return 1;
    my $argvs = shift // [];
    my $bccto = 'always-bcc@example.jp';

    push @$argvs, $bccto unless grep { $bccto eq $_ } @$argvs;
    return $nekor->error ? 0 : 1;
}

sub head {
    # @Description  Milter code for checking email headers
    # @Param <obj>  (Haineko::SMTPD::Response) Object
    # @Param <hash> (Ref->Hash) Email headers
    # @Return       (Integer) 1 = Allow, 0 = Reject
    my $class = shift;
    my $nekor = shift || return 1;
    my $argvs = shift // {};

    if( exists $argvs->{'subject'} && $argvs->{'subject'} =~ m/spam/i ) {
        # Reject if the subject contains text ``spam''
        $nekor->error(1);
        $nekor->dsn('5.7.1');
        $nekor->message( [ 'DO NOT SEND spam' ] );
    }

    return $nekor->error ? 0 : 1;
}

sub body {
    # @Description  Milter code for checking message body
    # @Param <obj>  (Haineko::SMTPD::Response) Object
    # @Param <msg>  (Ref->Scalar) Message body
    # @Return       (Integer) 1 = Allow, 0 = Reject
    my $class = shift;
    my $nekor = shift || return 1;
    my $argvs = shift // return 1;

    if( $$argvs =~ m|https?://| ) {
        # Do not include any URL in email body
        $nekor->error(1);
        $nekor->message( [ 'Not allowed to send an email including URL' ] );
    }

    return $nekor->error ? 0 : 1;
}

1;
__END__

=encoding utf8

=head1 NAME

Haineko::SMTPD::Milter::Example - Haineko milter for Example

=head1 DESCRIPTION

Example Haineko::SMTPD::Milter class.

=head1 SYNOPSIS

    use Haineko::SMTPD::Milter;
    Haineko::SMTPD::Milter->import( [ 'Example' ]);

=head1 IMPLEMENT MILTER METHODS (Override Haineko::SMTPD::Milter)

Each method is called from /submit at each phase of SMTP session. If you want to
reject the smtp connection, set required values into Haineko::SMTPD::Response 
object and return 0 or undef as a return value of each method. However you want
to only rewrite contents or passed your contents filter, return 1 or true as a 
return value.


=head2 B<conn( I<Haineko::SMTPD::Response>, I<REMOTE_HOST>, I<REMOTE_ADDR> )>

conn() method is for checking a client hostname and client IP address.

=head3 Arguments

=head4 B<Haineko::SMTPD::Response> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
Default SMTP status codes is 421 in this method.

=head4 B<REMOTE_HOST>

The host name of the message sender, as picked from HTTP REMOTE_HOST variable.

=head4 B<REMOTE_ADDR>

The host address, as picked from HTTP REMOTE_ADDR variable.


=head2 C<B<ehlo( I<Haineko::SMTPD::Response>, I<HELO_HOST> )>>

C<ehlo()> method is for checking a hostname passed as an argument of EHLO.

=head3 Arguments

=head4 C<B<Haineko::SMTPD::Response>> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 521 in this method.

=head4 C<B<HELO_HOST>>

Value defined in C<ehlo> field in HTTP POST JSON data, which should be the domain
name of the sending host or IP address enclosed square brackets.

=head2 C<B<mail( I<Haineko::SMTPD::Response>, I<ENVELOPE_SENDER> )>>

C<mail()> method is for checking an envelope sender address.

=head3 Arguments

=head4 C<B<Haineko::SMTPD::Response>> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 501, dsn is 5.1.8
in this method.

=head4 C<B<ENVELOPE_SENDER>>

Value defined in C<mail> field in HTTP POST JSON data, which should be the valid
email address.


=head2 C<B<rcpt( I<Haineko::SMTPD::Response>, I< [ ENVELOPE_RECIPIENTS ] > )>>

C<rcpt()> method is for checking envelope recipient addresses. Envelope recipient
addresses are password as an array reference.

=head3 Arguments

=head4 C<B<Haineko::SMTPD::Response>> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 553, dsn is 5.7.1
in this method.

=head4 C<B<ENVELOPE_RECIPIENTS>>

Values defined in C<rcpt> field in HTTP POST JSON data, which should be the 
valid email address.


=head2 C<B<head( I<Haineko::SMTPD::Response>, I< { EMAIL_HEADER } > )>>

C<head()> method is for checking email header. Email header is password as an
hash reference.

=head3 Arguments

=head4 C<B<Haineko::SMTPD::Response>> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 554, dsn is 5.7.1
in this method.

=head4 C<B<EMAIL_HEADER>>

Values defined in "header" field in HTTP POST JSON data.

=head2 C<B<body( I<Haineko::SMTPD::Response>, I< \EMAIL_BODY > )>>

C<boby()> method is for checking email body. Email body is password as an scalar
reference.

=head3 Arguments

=head4 C<B<Haineko::SMTPD::Response>> object

If your milter program rejects a message, set 1 by ->error(1), set error message
by ->message( [ 'Error message' ]), and override SMTP status code by ->code(), 
override D.S.N value by ->dsn(). Default SMTP status codes is 554, dsn is 5.6.0
in this method.

=head4 C<B<EMAIL_BODY>>

Value defined in "body" field in HTTP POST JSON data.

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
