use lib qw|./lib ./blib/lib|;
use strict;
use warnings;
use Haineko;
use Test::More;
use Haineko::JSON;
use IO::Socket::INET;
use Time::Piece;

my $servername = '127.0.0.1';
my $serverport = 2794;

my $nekosocket = undef;
my $htrequests = [];
my $emailfiles = [
    './tmp/make-author-test-1.json',
    './tmp/make-author-test-2.json',
];
my $methodargv = { 
    'PeerAddr' => $servername, 
    'PeerPort' => $serverport, 
    'proto'    => 'tcp',
};

for my $e ( @$emailfiles ) {

    ok( -f $e, '-f '.$e );
    ok( -r $e, '-r '.$e );
    ok( -s $e, '-s '.$e );

    my $t = Time::Piece->new;
    my $c = 0;
    my $x = undef;
    my $y = undef;

    $x= Haineko::JSON->loadfile( $e );
    isa_ok( $x, 'HASH' );
    isa_ok( $x->{'rcpt'}, 'ARRAY' );
    isa_ok( $x->{'header'}, 'HASH' );

    $x->{'header'}->{'subject'} = sprintf( 
        "MAKE TEST: [%s %s] %s", $t->ymd, $t->hms, $x->{'header'}->{'subject'} );
    $y = Haineko::JSON->dumpjson( $x );
    ok( length $y, 'Haineko::JSON->dumpjson' );

    $htrequests = [];
    push @$htrequests, sprintf( "POST /submit HTTP/1.0\n" );
    push @$htrequests, sprintf( "Host: 127.0.0.1\n" );
    push @$htrequests, sprintf( "Content-Type: application/json\n" );
    push @$htrequests, sprintf( "Content-Length: %d\n\n", length $y );
    push @$htrequests, sprintf( "%s\n\n", $y );

    $nekosocket = IO::Socket::INET->new( %$methodargv );
    select $nekosocket; $| = 1;
    select STDOUT;
    isa_ok( $nekosocket, 'IO::Socket::INET' );

    ok( $nekosocket->print( join( '', @$htrequests ) ), $e.' => /submit' );
    like( $nekosocket->getline, qr|\AHTTP/1.0 200 OK|, '200 OK' );

    while( my $r = $nekosocket->getline ) {
        $r =~ s/\r\n//g; chomp $r;

        if( length $r == 0 && $c == 0 ) {
            $c = 1;
            next;

        } else {
            ok( length $r );
            # {
            #   "smtp.remoteport": 63216,
            #   "smtp.addresser": "localpart@example.jp",
            #   "smtp.remoteaddr": "127.0.0.1",
            #   "smtp.queueid": "r92DiQB039703GHu",
            #   "smtp.response": {
            #     "code": 200,
            #     "host": "sendgrid.com",
            #     "command": "POST",
            #     "message": [
            #       "OK"
            #     ],
            #     "error": 0,
            #     "dsn": null,
            #     "mailer": "SendGrid"
            #   },
            #   "smtp.useragent": null,
            #   "smtp.stage": 0,
            #   "smtp.timestamp": {
            #     "datetime": "Wed Oct  2 13:44:26 2013",
            #     "unixtime": "1380689066"
            #   },
            #   "smtp.referer": null,
            #   "smtp.recipient": [
            #     "localpart@example.org"
            #   ]
            # }
            if( $c == 1 ) {
                # Content, Load as a JSON
                my $j = undef;
                my $s = undef;
                my $k = undef;

                $j = Haineko::JSON->loadjson( $r );
                isa_ok( $j, 'HASH' );

                is( $j->{'smtp.stage'}, 0, 'smtp.stage = 0' );
                ok( $j->{'smtp.queueid'}, 'smtp.queueid = '.$j->{'smtp.queueid'} );
                is( $j->{'smtp.referer'}, undef, 'smtp.referer = undef' );
                is( $j->{'smtp.useragent'}, undef, 'smtp.useragent = undef' );
                is( $j->{'smtp.addresser'}, $x->{'mail'}, 'smtp.addresser = '.$x->{'mail'} );
                is( $j->{'smtp.remoteaddr'}, '127.0.0.1', 'smtp.remoteaddr = 127.0.0.1' );
                ok( $j->{'smtp.remoteport'}, 'smtp.remoteport = '.$j->{'smtp.remoteport'} );

                $k = 'smtp.response';
                $s = $j->{ $k };
                isa_ok( $s, 'HASH' );
                isa_ok( $s->{'message'}, 'ARRAY' );
                is( $s->{'dsn'}, '2.0.0', sprintf( "%s->dsn = %s", $k, '2.0.0' ) );
                ok( $s->{'code'}, sprintf( "%s->code = %d", $k, $s->{'code'} ) );
                ok( $s->{'host'}, sprintf( "%s->host = %s", $k, $s->{'host'} ) );
                is( $s->{'error'}, 0, sprintf( "%s->error = %d", $k, 0 ) );
                ok( $s->{'mailer'}, sprintf( "%s->mailer = %s", $k, ( $s->{'mailer'} || undef ) ) );
                ok( $s->{'command'}, sprintf( "%s->command = %s", $k, $s->{'command'} ) );
                ok( $s->{'message'}->[0], sprintf( "%s->message->[0] = %s", $k, $s->{'message'}->[0] ) );


                $k = 'smtp.timestamp';
                $s = $j->{ $k };
                isa_ok( $s, 'HASH' );
                ok( $s->{'datetime'}, sprintf( "%s->datetime = %s", $k, $s->{'datetime'} ) );
                ok( $s->{'unixtime'}, sprintf( "%s->unixtime = %d", $k, $s->{'unixtime'} ) );
                
                $k = 'smtp.recipient';
                $s = $j->{ $k };
                isa_ok( $s, 'ARRAY' );
                for my $w ( @$s ) {
                    ok( $w, sprintf( "%s = %s", $k, $w ) );
                }

            } else {
                # Header
                like( $r, qr/:/, 'HTTP-HEADER => '.$r );
            }
        }
    }

    $nekosocket->close();
}

done_testing();
__END__
