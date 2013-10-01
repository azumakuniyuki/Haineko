#!/usr/bin/env perl
use strict;
use warnings;
use 5.010001;

BEGIN { 
    use FindBin;
    unshift @INC, "$FindBin::Bin/../lib";
}

use Haineko;
use Plack::Builder;

my $plackconds = {
    'Auth::Basic' => sub {
        return 0 unless $ENV{'HAINEKO_AUTH'};
        require Haineko::HTTPD::Auth;
        require Haineko::JSON;
        $Haineko::HTTPD::Auth::PasswordDB = Haineko::JSON->loadfile( $ENV{'HAINEKO_AUTH'} );
    },
};

my $plackargvs = {
    'Auth::Basic' => {
        'authenticator' => sub {
            my $u = shift;
            my $p = shift;
            my $v = { 'username' => $u, 'password' => $p };
            return Haineko::HTTPD::Auth->basic( %$v );
        },
    },
};

my $hainekoapp = builder {
    for my $e ( keys %$plackconds ) {
        my $r = $plackconds->{ $e }->();
        next unless $r;
        if( exists $plackargvs->{ $e } ) {
            # Enable Plack-Middleware with arguments
            enable $e, %{ $plackargvs->{ $e } };
        } else {
            # Enable Plack-Middleware
            enable $e;
        }
    };
    Haineko->start;
};
return $hainekoapp;
__END__
