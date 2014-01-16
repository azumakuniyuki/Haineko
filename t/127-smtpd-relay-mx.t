use lib qw|./lib ./blib/lib|;
use strict;
use warnings;
use Haineko::SMTPD::Relay::MX;
use Test::More;

my $modulename = 'Haineko::SMTPD::Relay::MX';
my $pkgmethods = [ 'new' ];
my $objmethods = [ 'sendmail' ];
my $methodargv = {
    'mail' => 'kijitora@from.haineko.org',
    'rcpt' => 'mikeneko@rcpt.haineko.org',
    'head' => { 
        'From', 'Kijitora <kijitora@from.haineko.org>',
        'To', 'Mikechan <mikenkeko@rcpt.haineko.org>',
        'Subject', 'Nyaa--',
    },
    'body' => \'Nyaaaaaaaaaaaaa',
    'attr' => {},
    'retry' => 0,
    'sleep' => 1,
    'timeout' => 2,
};
my $testobject = $modulename->new();

isa_ok $testobject, $modulename;
can_ok $modulename, @$pkgmethods;
can_ok $testobject, @$objmethods;

INSTANCE_METHODS: {

    for my $e ( qw/mail rcpt head body attr/ ) {
        is $testobject->$e, undef, '->'.$e.' => undef';
    }

    my $o = $modulename->new( %$methodargv );
    my $r = undef;
    my $m = undef;

    isa_ok $o->time, 'Time::Piece';
    ok $o->time, '->time => '.$o->time->epoch;

    $methodargv->{'time'} = Time::Piece->new;
    $o = $modulename->new( %$methodargv );
    isa_ok $o->time, 'Time::Piece';
    ok $o->time, '->time => '.$o->time->epoch;

    is $o->mail, $methodargv->{'mail'}, '->mail => '.$o->mail;
    is $o->rcpt, $methodargv->{'rcpt'}, '->rcpt => '.$o->rcpt;
    is $o->host, '', '->host => ""';
    is $o->port, 25, '->port => 25';
    is $o->body, $methodargv->{'body'}, '->body => '.$o->body;

    is ref $o->attr, 'HASH';
    is $o->timeout, 2, '->timeout => 2';
    is $o->retry, 0, '->retry => 1';
    is $o->sleep, 1, '->sleep => 1';
    is $o->sendmail, 0, '->sendmail => 0';

    $r = $o->response;
    $m = shift @{ $o->response->message };

    is $r->dsn, undef, '->response->dsn => undef';
    is $r->code, 421, '->response->code => 421';
    is $r->host, undef, '->response->host => undef';
    is $r->port, 25, '->response->port => 25';
    is $r->rcpt, $methodargv->{'rcpt'}, '->response->rcpt => '.$r->rcpt;
    is $r->error, 1, '->response->error=> 1';
    is $r->command, 'CONN', '->response->command => CONN';
    like $m, qr/Cannot connect SMTP Server/, '->response->message => '.$m;
}

done_testing;
__END__
