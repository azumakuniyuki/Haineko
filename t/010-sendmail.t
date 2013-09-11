use lib qw|./lib ./blib/lib|;
use strict;
use warnings;
use Haineko;
use Test::More;
use JSON::Syck;
use Plack::Test;
use HTTP::Request;

my $nekochan = Haineko->start;
my $request1 = undef;
my $response = undef;
my $contents = undef;
my $esmtpres = undef;
my $callback = undef;

my $nekotest = sub {
    $callback = shift;
    $request1 = HTTP::Request->new( 'GET' => 'http://127.0.0.1:2794/submit' );
    $response = $callback->( $request1 );
    $contents = JSON::Syck::Load( $response->content );
    $esmtpres = $contents->{'smtp.response'};

    isa_ok $request1, 'HTTP::Request';
    isa_ok $response, 'HTTP::Response';
    isa_ok $contents, 'HASH';
    isa_ok $esmtpres, 'HASH';

    is $response->code, 405;
    is $esmtpres->{'dsn'}, undef;
    is $esmtpres->{'host'}, '127.0.0.1';
    is $esmtpres->{'code'}, 421;
    is $esmtpres->{'error'}, 1;
    is $esmtpres->{'mailer'}, undef;
    is $esmtpres->{'message'}->[0], 'GET method not supported';
    is $esmtpres->{'command'}, 'HTTP';
};
test_psgi $nekochan, $nekotest;

my $hostname = qx|hostname|; chomp $hostname;
my $jsondata = {
    'JSON00' => {
        'json' => '{ neko', 'data' => '', 
        'code' => 421, 'dsn' => undef, 'status' => 400, 'command' => 'HTTP',
        'mailer' => undef, 'message' => 'Malformed JSON string',
    },
    'EHLO00' => {
        'json' => q(), 'data' => { 'ehlo' => q() },
        'code' => 501, 'dsn' => '5.0.0', 'status' => 400, 'command' => 'EHLO',
        'message' => 'EHLO requires domain address',
    },
    'EHLO01' => {
        'json' => q(), 'data' => { 'ehlo' => 0 },
        'code' => 501, 'dsn' => '5.0.0', 'status' => 400, 'command' => 'EHLO',
        'message' => 'Invalid domain name',
    },
    'MAIL00' => {
        'json' => q(), 'data' => { 'ehlo' => 'example.jp' },
        'code' => 501, 'dsn' => '5.5.2', 'status' => 400, 'command' => 'MAIL',
        'message' => 'Syntax error in parameters scanning "FROM"',
    },
    'MAIL01' => {
        'json' => q(), 
        'data' => { 'ehlo' => 'example.jp', 'mail' => 'kijitora' },
        'code' => 553, 'dsn' => '5.5.4', 'status' => 400, 'command' => 'MAIL',
        'message' => 'Domain name required for sender address',
    },
    'RCPT00' => {
        'json' => q(), 
        'data' => { 'ehlo' => 'example.jp', 'mail' => 'kijitora@example.jp' },
        'code' => 553, 'dsn' => '5.0.0', 'status' => 400, 'command' => 'RCPT',
        'message' => 'User address required',
    },
    'RCPT01' => {
        'json' => q(), 
        'data' => { 
            'ehlo' => 'example.jp', 
            'mail' => 'kijitora@example.jp',
            'rcpt' => [ 'kijitora' ],
        },
        'code' => 553, 'dsn' => '5.1.5', 'status' => 400, 'command' => 'RCPT',
        'message' => 'Recipient address is invalid',
    },
    'RCPT02' => {
        'json' => q(), 
        'data' => { 
            'ehlo' => 'example.jp', 
            'mail' => 'kijitora@example.jp',
            'rcpt' => [ 'kijitora@example.org' ],
        },
        'code' => 553, 'dsn' => '5.7.1', 'status' => 403, 'command' => 'RCPT',
        'message' => 'Recipient address is not permitted',
    },
    'RCPT03' => {
        'json' => q(), 
        'data' => { 
            'ehlo' => 'example.jp', 
            'mail' => 'kijitora@example.jp',
            'rcpt' => [
                '1@'.$hostname,
                '2@'.$hostname,
                '3@'.$hostname,
                '4@'.$hostname,
                '5@'.$hostname,
            ],
        },
        'code' => 452, 'dsn' => '4.5.3', 'status' => 403, 'command' => 'RCPT',
        'message' => 'Too many recipients',
    },
    'DATA01' => {
        'json' => q(), 
        'data' => { 
            'ehlo' => 'example.jp', 
            'mail' => 'kijitora@example.jp',
            'rcpt' => [
                'haineko@'.$hostname,
            ],
        },
        'code' => 500, 'dsn' => '5.6.0', 'status' => 400, 'command' => 'DATA',
        'message' => 'Message body is empty',
    },
    'DATA02' => {
        'json' => q(), 
        'data' => { 
            'ehlo' => 'example.jp', 
            'mail' => 'kijitora@example.jp',
            'rcpt' => [
                'haineko@'.$hostname,
            ],
            'body' => 'ニャー',
        },
        'code' => 500, 'dsn' => '5.6.0', 'status' => 400, 'command' => 'DATA',
        'message' => 'Subject header is empty',
    },
};

my $nekopost = sub {
    $callback = shift;

    for my $e ( keys %$jsondata ) {
        $request1 = HTTP::Request->new( 'POST' => 'http://127.0.0.1:2794/submit' );
        $request1->header( 'Content-Type' => 'application/json' );

        my $d = $jsondata->{ $e };
        my $j = $d->{'json'} || JSON::Syck::Dump( $d->{'data'} );

        $request1->content( $j );
        $response = $callback->( $request1 );
        $contents = JSON::Syck::Load( $response->content );
        $esmtpres = $contents->{'smtp.response'};

        isa_ok $request1, 'HTTP::Request';
        isa_ok $response, 'HTTP::Response';
        isa_ok $contents, 'HASH';
        isa_ok $esmtpres, 'HASH';

        ok $response->is_error;
        is $response->header('Content-Type'), 'application/json';
        is $response->code, $d->{'status'}, sprintf( "[%s] HTTP Status = %s", $e, $d->{'status'} );
        is $esmtpres->{'host'}, '127.0.0.1', sprintf( "[%s] host = 127.0.0.1", $e );
        is $esmtpres->{'error'}, 1, sprintf( "[%s] error = 1", $e );

        for my $r ( keys %$d ) {
            next if $r =~ m/(?:status|json|data|message)/;
            is $esmtpres->{ $r }, $d->{ $r }, sprintf( "[%s] SMTP %s = %s", $e, $r, ( $d->{ $r } || q() ) );
        }

        is $esmtpres->{'message'}->[0], $d->{'message'}, sprintf( "[%s] SMTP message = %s", $e, $d->{'message'} );
        is substr( $esmtpres->{'code'}, 0, 1 ), substr( $esmtpres->{'dsn'}, 0, 1 ) if $esmtpres->{'dsn'};
    }
};
test_psgi $nekochan, $nekopost;
done_testing();
__END__








my $t = Test::Mojo->new('Haineko');
my $c = { 'Content-Type' => 'application/json' };
my $r = undef;  # Response
my $p = {};     # JSON as a Hash reference
my $j = q();    # JSON as a String
my $h = qx(hostname); chomp $h;




done_testing();

