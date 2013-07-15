use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use JSON::Syck;
use Mojo::UserAgent;
use lib qw(./t/lib ./dist/lib ./lib);

my $t = Test::Mojo->new('Haineko');
my $c = { 'Content-Type' => 'application/json' };
my $r = undef;  # Response
my $p = {};     # JSON as a Hash reference
my $j = q();    # JSON as a String


CONNECT: {
    $r = $t->get_ok('/submit')->status_is(405);
    $r = $t->post_ok('/submit')->status_is(400);

    isa_ok( $t, 'Test::Mojo' );
    ok $r->header_is( 'Server' => 'Mojolicious (Perl)' );
    ok $r->header_is( 'X-Content-Type-Options' => 'nosniff' );
    ok $r->header_is( 'Content-Type' => 'application/json' );
}

JSON: {
    $j = '{ neko';
    $r = $t->post_ok( '/submit', $c, $j );

    ok $r->json_is( '/smtp.response/dsn', undef );
    ok $r->json_is( '/smtp.response/code', 421 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'HTTP' );
    ok $r->json_is( '/smtp.response/message', [ 'Malformed JSON string' ] );
}

EHLO: {
    # /
    $p = { 'ehlo' => q() };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );

    ok $r->json_is( '/smtp.response/dsn', '5.0.0' );
    ok $r->json_is( '/smtp.response/code', 501 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'EHLO' );
    ok $r->json_is( '/smtp.response/message', [ 'EHLO requires domain address' ] );

    # /ehlo=0
    $p = { 'ehlo' => 0 };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );

    #$r = $t->post_ok( '/submit', 'form' => $j );
    ok $r->json_is( '/smtp.response/dsn', '5.0.0' );
    ok $r->json_is( '/smtp.response/code', 501 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'EHLO' );
    ok $r->json_is( '/smtp.response/message', [ 'Invalid domain name' ] );

    # /ehlo=example.jp
    $p = { 'ehlo' => 'example.jp' };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );

    ok $r->json_is( '/smtp.response/dsn', '5.5.2' );
    ok $r->json_is( '/smtp.response/code', 501 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'MAIL' );
    ok $r->json_is( '/smtp.response/message', [ 'Syntax error in parameters scanning "FROM"' ] );
}

MAIL: {
    # mail=kijitora
    $p = { 'ehlo' => 'example.jp', 'mail' => 'kijitora' };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );
    
    ok $r->json_is( '/smtp.response/dsn', '5.5.4' );
    ok $r->json_is( '/smtp.response/code', 553 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'MAIL' );
    ok $r->json_is( '/smtp.response/message', [ 'Domain name required for sender address' ] );

    # /mail=kijitora@example.jp
    $p = { 'ehlo' => 'example.jp', 'mail' => 'kijitora@example.jp' };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );

    ok $r->json_is( '/smtp.response/dsn', '5.0.0' );
    ok $r->json_is( '/smtp.response/code', 553 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'RCPT' );
    ok $r->json_is( '/smtp.response/message', [ 'User address required' ] );
}

RCPT: {
    # /rcpt=kijitora
    $p = { 
        'ehlo' => 'example.jp', 
        'mail' => 'kijitora@example.jp', 
        'rcpt' => [ 'kijitora' ],
    };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );
    
    ok $r->json_is( '/smtp.response/dsn', '5.1.5' );
    ok $r->json_is( '/smtp.response/code', 553 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'RCPT' );
    ok $r->json_is( '/smtp.response/message', [ 'Recipient address is invalid' ] );

    # /rcpt=...
    $p = { 
        'ehlo' => 'example.jp', 
        'mail' => 'kijitora@example.jp', 
        'rcpt' => [ 
            '1@example.org',
            '2@example.org',
            '3@example.org',
            '4@example.org',
            '5@example.org',
        ],
    };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );
    
    ok $r->json_is( '/smtp.response/dsn', '4.5.3' );
    ok $r->json_is( '/smtp.response/code', 452 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'RCPT' );
    ok $r->json_is( '/smtp.response/message', [ 'Too many recipients' ] );
}

BODY: {
    $p = { 
        'ehlo' => 'example.jp', 
        'mail' => 'kijitora@example.jp', 
        'rcpt' => [ 'haineko@example.org' ],
    };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );
    
    ok $r->json_is( '/smtp.response/dsn', '5.6.0' );
    ok $r->json_is( '/smtp.response/code', 500 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'DATA' );
    ok $r->json_is( '/smtp.response/message', [ 'Message body is empty' ] );

    $p = { 
        'ehlo' => 'example.jp', 
        'mail' => 'kijitora@example.jp', 
        'rcpt' => [ 'haineko@example.org' ],
        'body' => 'ニャー',
    };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );
    
    ok $r->json_is( '/smtp.response/dsn', '5.6.0' );
    ok $r->json_is( '/smtp.response/code', 500 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'DATA' );
    ok $r->json_is( '/smtp.response/message', [ 'Subject header is empty' ] );
}

CANNOT_CONNECT: {

    $p = { 
        'ehlo' => 'example.jp', 
        'mail' => 'kijitora@example.jp', 
        'rcpt' => [ 'haineko@example.org' ],
        'body' => 'ニャー',
        'header' => {
            'subject' => 'にゃんこ',
        },
    };
    $j = JSON::Syck::Dump $p;
    $r = $t->post_ok( '/submit', $c, $j );
    
    ok $r->json_is( '/smtp.response/dsn', undef );
    ok $r->json_is( '/smtp.response/code', 421 );
    ok $r->json_is( '/smtp.response/error', 1 );
    ok $r->json_is( '/smtp.response/command', 'CONN' );
    ok $r->json_is( '/smtp.response/message', [ 'Cannot connect SMTP Server' ] );
}

done_testing();

