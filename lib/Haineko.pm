package Haineko;
use 5.010001;
use Mojo::Base 'Mojolicious';
use Path::Class;
use Time::Piece;
use JSON::Syck;
use Data::Dumper;

our $VERSION = '0.0.1';
our $SYSNAME = 'Haineko';

sub startup
{
	my $self = shift;
	my $home = new Path::Class::File(__FILE__);
	my $root = $home->dir->resolve->absolute->parent;
	my $conf = sprintf( "%s/etc/haineko.cf", $root->stringify );

	my $hypnotoadc = {
		'listen' => [ 'http://*:2794', 'https://*:20794' ],
		'pid_file' => 'run/haineko.pid',
	};
	my $serverconf = {
		'smtpd' => { 
			'system' => $SYSNAME,
			'max_message_size' => 4194304,
			'max_rcpts_per_message' => 4,
		},
		'daemon' => {
			'session' => { 
				'secret'  => 'haineko',
				'expires' => 300,
			},
		},
	};
	my $mailerconf = {
		'mail' => sprintf( "%s/etc/sendermt", $root->stringify ),
		'auth' => sprintf( "%s/etc/authinfo", $root->stringify ),
		'rcpt' => sprintf( "%s/etc/mailertable", $root->stringify ),
	};
	my $accessconf = {
		'conn' => sprintf( "%s/etc/relayhosts", $root->stringify ),
		'rcpt' => sprintf( "%s/etc/recipients", $root->stringify ),
	};

	# Load configurations
	eval { $serverconf = JSON::Syck::LoadFile( $conf ) };
	$self->app->log->fatal( $@ ) if $@;

	eval { $hypnotoadc = JSON::Syck::LoadFile( sprintf( "%s/etc/hypnotoad.cf", $root->stringify ) ) };
	$self->app->log->info( $@ ) if $@;

	$serverconf->{'smtpd'}->{'system'} = $SYSNAME;
	$serverconf->{'smtpd'}->{'version'} = $VERSION;

	ROUTINGTABLES_AND_ACCESSCONTROL: {
		# Override configuration files
		for my $e ( keys %$mailerconf )
		{
			my $f = $serverconf->{'smtpd'}->{'routing'}->{ $e } || q();
			next unless defined $f;
			next unless length $f;

			$f = sprintf( "%s/etc/%s", $root->stringify, $f ) unless $f =~ m{\A[/.]};
			next if( not -f $f || not -r _ || not -s _ );
			$mailerconf->{ $e } = $f;
		}

		for my $e ( keys %$accessconf )
		{
			my $f = $serverconf->{'smtpd'}->{'access'}->{ $e } || q();
			next unless defined $f;
			next unless length $f;

			$f = sprintf( "%s/etc/%s", $root->stringify, $f ) unless $f =~ m{\A[/.]};
			next if( not -f $f || not -r _ || not -s _ );
			$accessconf->{ $e } = $f;
		}
	}

	$self->config( 'hypnotoad' => $hypnotoadc );
	$self->session( 'default_expiration' => $serverconf->{'session'}->{'expires'} );
	$self->session( 'cookie_name' => 'haineko' );
	$self->session( 'secret' => $serverconf->{'session'}->{'secret'} );
	$self->defaults( 'cf' => $serverconf->{'smtpd'} ) if exists $serverconf->{'smtpd'};
	$self->defaults( 'mc' => $mailerconf );
	$self->defaults( 'rc' => $accessconf );

	# Helper
	$self->helper(
		'myname' => sub {
			return sprintf( "%s/%s", $SYSNAME, $VERSION );
		}
	);

	# Route to controller
	my $r = $self->routes;	# Route
	my $b = undef;		# Bridge

	$r->route('/')->to( 'cb' => sub { 
			my $self = shift;
			return $self->render( 'text' => $self->myname );
		}
	);
	$r->route( '/submit' )->to( 'controller' => 'ctrl-submit', 'action' => 'sendmail' );

}

1;
__END__

=pod
=encoding utf-8
=head1 NAME

Haineko - HTTP API into ESMTP

=head1 DESCRIPTION

	Haineko runs as a web server on port 2794 by Mojolicious

=head1 SYNOPSYS

	$ hypnotoad script/haineko

=head1 EMAIL SUBMISSION

=head2 URL

	http://127.0.0.1:2794/submit

=head2 PARAMETERS(JSON)

To send email via Haineko, POST email data as a JSON format like the
following:

	{ 
		ehlo: 'your-host-name.as.fqdn'
		mail: 'kijitora@example.jp'
		rcpt: [ 'cats@cat-ml.kyoto.example.jp' ]
		header: { 
			from: 'kijitora <kijitora@example.jp>'
			subject: 'About next meeting'
			relpy-to: 'cats <ml@cat-ml.kyoto.example.jp>'
			charset: 'ISO-2022-JP'
		}
		body: 'Next meeting opens at midnight on next thursday'
	}

	$ curl 'http://127.0.0.1:2794/submit' -X POST \
	  -d '{ ehlo: "[127.0.0.1]", mail: "kijitora@example.jp", ... }'

=head2 PARAMETERS(URL)

	ehlo = Client Host name or IP address for SMTP-EHLO

	mail = Envelope sender address

	rcpt = Envelope recipient address

	body = Email body content

	header.from = From: header

	header.subject = Subject: header

	header.charset = Character set for Content-Type: header

	$ telnet 127.0.0.1 2794
	...
	GET /submit?ehlo=[127.0.0.1]&mail=kijitora@example.jp&...


=head1 CONFIGURATION FILES

=head2 etc/haineko.cf

	Main configuration file for Haineko.

=head2 etc/mailertable

	Recipient's domain part based routing table. This file is taken precedence
	over the routing table defined in etc/sendermt for deciding the route.

=head2 etc/sendermt

	Sender's domain part based routing table.

=head2 etc/authinfo

	Credential information for SMTP-AUTH.

=head2 etc/relayhost

	Permitted hosts or network table for relaying via /submit

=head1 REPOSITORY

https://github.com/azumakuniyuki/haineko

=head1 AUTHOR

azumakuniyuki E<lt>perl.org [at] azumakuniyuki.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
