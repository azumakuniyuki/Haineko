package Haineko::Relay::SendGrid;
use parent 'Haineko::Relay';
use strict;
use warnings;
use Furl;
use JSON::Syck;
use Time::Piece;
use Haineko::Response;
use Encode;

sub new
{
	my $class = shift;
	my $argvs = { @_ };

	$argvs->{'sleep'} ||= 5;
	$argvs->{'timeout'} ||= 30;
	return bless $argvs, __PACKAGE__;
}

sub sendmail
{
	my $self = shift;

	if( ! $self->{'username'} || ! $self->{'password'} )
	{
		my $r = {
			'code' => 400,
			'error' => 1,
			'message' => [ 'Empty API-USER or API-KEY' ],
			'command' => 'POST',
		};
		$self->response( Haineko::Response->new( %$r ) );
		return 0
	}

	my $sendgridif = 'https://sendgrid.com/api/mail.send.json';
	my $parameters = {
		'to' => $self->{'rcpt'},
		'from' => $self->{'mail'},
		'date' => $self->{'head'}->{'Date'},
		'subject' => $self->{'head'}->{'Subject'},
		'headers' => q(),
		'api_key' => $self->{'password'} // q(),
		'api_user' => $self->{'username'} // q(),
		'fromname' => $self->{'head'}->{'From'},
		'x-smtpapi' => q(),
	};

	my $usedheader = [ 'Date', 'Subject', 'From' ];
	my $jsonheader = {};
	my $identifier = shift [ split( '@', $self->{'head'}->{'Message-Id'} ) ];

	for my $e ( keys %{ $self->{'head'} } )
	{
		next unless $e =~ m/\AX-/;
		$jsonheader->{ $e } = $self->{'head'}->{ $e };
	}
	$jsonheader->{'X-Haineko-QueueId'} = $identifier;
	$jsonheader->{'X-Haineko-Message-Id'} = $self->{'head'}->{'Message-Id'};
	$parameters->{'headers'} = JSON::Syck::Dump $jsonheader;

	$jsonheader = { 'unique_args' => { 'queueid' => $identifier } };
	$parameters->{'x-smtpapi'} = JSON::Syck::Dump $jsonheader;
	$parameters->{'text'}  = Encode::encode( 'UTF-8', ${ $self->{'body'} } );
	$parameters->{'text'} .= qq(\n\n);


	my $methodargv = { 
		'agent' => $self->{'ehlo'},
		'timeout' => $self->{'timeout'},
		'ssl_opts' => { 'SSL_verify_mode' => 0 }
	};
	my $httpclient = Furl->new( %$methodargv );
	my $htresponse = undef;
	my $retryuntil = $self->{'retry'} || 0;
	my $smtpstatus = 0;

	my $sendmailto = sub {
		$htresponse = $httpclient->post( $sendgridif, undef, $parameters );

		return 0 unless defined $htresponse;
		return 0 unless $htresponse->is_success;

		$smtpstatus = 1;
		return 1;
	};

	while(1)
	{
		last if $sendmailto->();
		last if $retryuntil == 0;

		$retryuntil--;
		sleep $self->{'sleep'};
	}

	if( defined $htresponse )
	{
		my $htcontents = undef;
		my $nekoparams = { 
			'code' => $htresponse->code,
			'error' => $htresponse->is_success ? 0 : 1,
			'message' => [ $htresponse->message ],
			'command' => 'POST',
		};

		eval { $htcontents = JSON::Syck::Load( $htresponse->body ) };

		while(1)
		{
			last if $@;
			last unless ref $htcontents eq 'HASH';
			last unless exists $htcontents->{'message'};
			last unless $htcontents->{'message'} eq 'error';

			push @{ $nekoparams->{'message'} }, @{ $htcontents->{'errors'} };
			last;
		}
		$self->response( Haineko::Response->new( %$nekoparams ) );
	}

	return $smtpstatus;
}

sub getbounce
{
	my $self = shift;

	return 0 if( ! $self->{'username'} || ! $self->{'password'} );

	my $sendgridif = 'https://sendgrid.com/api/bounces.get.json';
	my $timepiece1 = gmtime;
	my $yesterday1 = Time::Piece->new( $timepiece1->epoch - 86400 );
	my $parameters = {
		'date' => 1,
		'days' => 1,
		'email' => $self->{'rcpt'},
		'limit' => 1,
		'api_key' => $self->{'password'} // q(),
		'api_user' => $self->{'username'} // q(),
		'start_date' => $yesterday1->ymd('-'),
	};

	my $methodargv = { 
		'agent' => $self->{'ehlo'},
		'timeout' => $self->{'timeout'},
		'ssl_opts' => { 'SSL_verify_mode' => 0 }
	};
	my $httpclient = Furl->new( %$methodargv );
	my $htresponse = undef;
	my $retryuntil = $self->{'retry'} || 0;
	my $httpstatus = 0;

	my $getbounced = sub {
		$htresponse = $httpclient->post( $sendgridif, undef, $parameters );

		return 0 unless defined $htresponse;
		return 0 unless $htresponse->is_success;

		$httpstatus = 1;
		return 1;
	};

	while(1)
	{
		last if $getbounced->();
		last if $retryuntil == 0;

		$retryuntil--;
		sleep $self->{'sleep'};
	}

	if( defined $htresponse )
	{
		my $htcontents = undef;
		my $nekoparams = undef;
		eval { $htcontents = JSON::Syck::Load( $htresponse->body ) };

		while(1)
		{
			last if $@;
			last unless ref $htcontents eq 'ARRAY';
			last unless scalar @$htcontents;

			my $r = shift @$htcontents;
			last unless ref $r eq 'HASH';

			$nekoparams = { 
				'message' => [ $r->{'reason'} ],
				'command' => 'POST',
			};
			$self->response( Haineko::Response->p( %$nekoparams ) );
			last;
		}
	}
	return $httpstatus;
}

1;
__END__

=encoding utf8

=head1 NAME

Haineko::Relay::SendGrid - SendGrid Web API class for sending email

=head1 DESCRIPTION

Send an email to a recipient via SendGrid using Web API.

=head1 SYNOPSIS

	use Haineko::Relay::SendGrid;
	my $h = { 'Subject' => 'Test', 'To' => 'neko@example.org' };
	my $v = { 
		'username' => 'api_user', 'password' => 'api_key',
		'ehlo' => 'UserAgent name for Furl',
		'mail' => 'kijitora@example.jp', 'rcpt' => 'neko@example.org',
		'head' => $h, 'body' => 'Email message',
	};
	my $e = Haineko::Relay::SendGrid->new( %$v );
	my $s = $e->sendmail;

	print $s;			# 0 = Failed to send, 1 = Successfully sent
	print $e->response->error;	# 0 = No error, 1 = Error
	print $e->response->dsn;	# always returns undef
	print $e->response->code;	# HTTP response code from SendGrid API

	warn Data::Dumper::Dumper $e->response;
	$VAR1 = bless( {
			 'dsn' => undef,
			 'error' => 0,
			 'code' => '200',
			 'message' => [ 'OK' ],
			 'command' => 'POST'
		       }, 'Haineko::Response' );

=head1 CLASS METHODS

=head2 B<new( I<%arguments> )>

new() is a constructor of Haineko::Relay::SendGrid

	my $e = Haineko::Relay::SendGrid->new( 
			'username' => 'username',	# API User for SendGrid
			'password' => 'password',	# API Key for SendGrid
			'timeout' => 60,		# Timeout for Furl
			'attr' => {			# 
				'content_type' => 'text/plain'
			},
			'head' => {			# Email header
				'Subject' => 'Test',
				'To' => 'neko@example.org',
			},
			'body' => 'Email message',	# Email body
			'mail' => 'kijitora@example.jp',# Envelope sender
			'rcpt' => 'cat@example.org',	# Envelope recipient
	);

=head1 INSTANCE METHODS

=head2 B<sendmail>

sendmail() will send email to the specified recipient(rcpt) via specified host.

	my $e = Haineko::Relay::SendGrid->new( %argvs );
	print $e->sendmail;	# 0 = Failed to send, 1 = Successfully sent

	print Data::Dumper::Dumper $e->response; # Dumps Haineko::Response object

=head2 B<getbounce>

getbounce() retrieve bounced records using SendGrid API.

	my $e = Haineko::Relay::SendGrid->new( %$argvs );
	print $e->getbounce;	# 0 = No bounce or failed to retrieve
				# 1 = One or more bounced records retrieved

	print Data::Dumper::Dumper $e->response;
	$VAR1 = bless( {
                 'dsn' => '5.1.1',
                 'error' => 1,
                 'code' => '550',
                 'message' => [
                                '550 5.1.1 <user@example.org>... User unknown '
                              ],
                 'command' => 'POST'
               }, 'Haineko::Response' );

=head1 REPOSITORY

https://github.com/azumakuniyuki/haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
