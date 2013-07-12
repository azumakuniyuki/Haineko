use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use JSON::Syck;
use lib qw(./t/lib ./dist/lib ./lib);

my $t = Test::Mojo->new('Haineko');
my $r = $t->get_ok('/submit')->status_is(400);
my $j = {};

CONNECT: {
	ok $r->header_is( 'Server' => 'Mojolicious (Perl)' );
	ok $r->header_is( 'X-Content-Type-Options' => 'nosniff' );
	ok $r->header_is( 'Content-Type' => 'application/json' );
}

EHLO: {
	# /
	ok $r->json_is( '/smtp.response/dsn', '5.0.0' );
	ok $r->json_is( '/smtp.response/code', 501 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'EHLO' );
	ok $r->json_is( '/smtp.response/message', [ 'EHLO requires domain address' ] );

	# /ehlo=0
	$j = { 'ehlo' => 0 };
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '5.0.0' );
	ok $r->json_is( '/smtp.response/code', 501 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'EHLO' );
	ok $r->json_is( '/smtp.response/message', [ 'Invalid domain name' ] );

	# /ehlo=example.jp
	$j = { 'ehlo' => 'example.jp' };
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '5.5.2' );
	ok $r->json_is( '/smtp.response/code', 501 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'MAIL' );
	ok $r->json_is( '/smtp.response/message', [ 'Syntax error in parameters scanning "FROM"' ] );
}

MAIL: {
	# mail=kijitora
	$j = { 'ehlo' => 'example.jp', 'mail' => 'kijitora' };
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '5.5.4' );
	ok $r->json_is( '/smtp.response/code', 553 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'MAIL' );
	ok $r->json_is( '/smtp.response/message', [ 'Domain name required for sender address' ] );

	# /mail=kijitora@example.jp
	$j = { 'ehlo' => 'example.jp', 'mail' => 'kijitora@example.jp' };
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '5.0.0' );
	ok $r->json_is( '/smtp.response/code', 553 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'RCPT' );
	ok $r->json_is( '/smtp.response/message', [ 'User address required' ] );
}

RCPT: {
	# /rcpt=kijitora
	$j = { 'ehlo' => 'example.jp', 'mail' => 'kijitora@example.jp', 'rcpt' => [ 'kijitora' ] };
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '5.1.5' );
	ok $r->json_is( '/smtp.response/code', 553 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'RCPT' );
	ok $r->json_is( '/smtp.response/message', [ 'Recipient address is invalid' ] );

	# /rcpt=...
	$j = { 
		'ehlo' => 'example.jp', 
		'mail' => 'kijitora@example.jp', 
		'rcpt' => '1@example.org,2@example.org,3@example.org,4@example.org,5@example.org',
	};
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '4.5.3' );
	ok $r->json_is( '/smtp.response/code', 452 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'RCPT' );
	ok $r->json_is( '/smtp.response/message', [ 'Too many recipients' ] );
}

BODY: {
	$j = { 
		'ehlo' => 'example.jp', 
		'mail' => 'kijitora@example.jp', 
		'rcpt' => 'haineko@example.org',
	};
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '5.6.0' );
	ok $r->json_is( '/smtp.response/code', 500 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'DATA' );
	ok $r->json_is( '/smtp.response/message', [ 'Message body is empty' ] );

	$j = { 
		'ehlo' => 'example.jp', 
		'mail' => 'kijitora@example.jp', 
		'rcpt' => 'haineko@example.org',
		'body' => 'ニャー',
	};
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', '5.6.0' );
	ok $r->json_is( '/smtp.response/code', 500 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'DATA' );
	ok $r->json_is( '/smtp.response/message', [ 'Subject header is empty' ] );
}

CANNOT_CONNECT: {

	$j = { 
		'ehlo' => 'example.jp', 
		'mail' => 'kijitora@example.jp', 
		'rcpt' => 'haineko@example.org',
		'body' => 'ニャー',
		'header.subject' => 'にゃんこ',
	};
	$r = $t->post_ok( '/submit', 'form' => $j );
	ok $r->json_is( '/smtp.response/dsn', undef );
	ok $r->json_is( '/smtp.response/code', 400 );
	ok $r->json_is( '/smtp.response/error', 1 );
	ok $r->json_is( '/smtp.response/command', 'CONN' );
	ok $r->json_is( '/smtp.response/message', [ 'Cannot connect SMTP Server' ] );
}

done_testing();

