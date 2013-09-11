package Haineko::HTTPD;
use strict;
use warnings;
use 5.010001;
use Try::Tiny;
use Path::Class;
use Haineko::JSON;
use Haineko::Default;
use Class::Accessor::Lite;
use Haineko::HTTPD::Router;
use Haineko::HTTPD::Request;
use Haineko::HTTPD::Response;

my $rwaccessors = [
    'debug',    # (Integer) $HAINEKO_DEBUG
    'router',   # (Haineko::HTTPD::Router) Routing table
    'request',  # (Haineko::HTTPD::Request) HTTP Request
    'response', # (Haineko::HTTPD::Response) HTTP Response
];
my $roaccessors = [
    'name',     # (String) System name
    'conf',     # (Ref->Hash) Haineko Configuration
    'root',     # (Path::Class::Dir) Root directory
];
my $woaccessors = [];
Class::Accessor::Lite->mk_accessors( @$rwaccessors );
Class::Accessor::Lite->mk_ro_accessors( @$roaccessors );

sub new {
    my $class = shift;
    my $argvs = { @_ };

    my $hainekodir = $argvs->{'root'} || $ENV{'HAINEKO_ROOT'} || '.';
    my $hainekocfg = $argvs->{'conf'} || $ENV{'HAINEKO_CONF'} || q();
    my $milterlibs = [];

    $argvs->{'name'} = 'Haineko';
    $argvs->{'root'} = Path::Class::Dir->new( $hainekodir ) if $hainekodir;
    $argvs->{'conf'} = Haineko::JSON->loadfile( $hainekocfg ) || Haineko::Default->conf;
    $milterlibs = $argvs->{'conf'}->{'smtpd'}->{'milter'}->{'libs'} || [];

    for my $e ( 'mailer', 'access' ) {
        # Override configuration files
        #   mailertable files and access controll files are overridden the file
        #   which defined in etc/haineko.cf: 
        #
        my $f = $argvs->{'conf'}->{'smtpd'}->{ $e } || Haineko::Default->table( $e );
        my $g = undef;

        for my $ee ( keys %$f ) {
            # etc/{sendermt,mailertable,authinfo}, etc/{relayhosts,recipients}
            # Get an absolute path of each table
            #
            $g = $f->{ $ee };
            $g = sprintf( "%s/etc/%s", $hainekodir, $g ) unless $g =~ m|\A[/.]|;

            if( $ENV{'HAINEKO_DEBUG'} ) {
                # When the value of $HAINEKO_DEBUG is 1,
                # etc/{mailertable,authinfo,sendermt,recipients,relayhosts}-debug
                # are used as a configuration files for debugging.
                #
                if( not $g =~ m/[-]debug\z/ ) {
                    $g .= '-debug' if( -f $g.'-debug' && -s _ && -r _ );
                }
            }
            $argvs->{'conf'}->{'smtpd'}->{ $e }->{ $ee } = $g;
        }
    } # End of for(TABLE FILES)

    if( ref $milterlibs eq 'ARRAY' ) {
        # Load milter lib path
        require Haineko::SMTPD::Milter;
        Haineko::SMTPD::Milter->libs( $milterlibs );
    }

    $argvs->{'debug'}      = $ENV{'HAINEKO_DEBUG'} ? 1 : 0;
    $argvs->{'router'}   ||= Haineko::HTTPD::Router->new;
    $argvs->{'request'}  ||= Haineko::HTTPD::Request->new;
    $argvs->{'response'} ||= Haineko::HTTPD::Response->new;

    return bless $argvs, __PACKAGE__;
}

sub start {
    my $class = shift;
    my $nyaaa = sub {
        my $hainekoenv = shift;
        my $htresponse = undef;
        my $requestnya = Haineko::HTTPD::Request->new( $hainekoenv );
        my $contextnya = $class->new( 'request' => $requestnya );

        local *Haineko::HTTPD::context = sub { $contextnya };
        $htresponse = $class->startup( $contextnya, $requestnya );

        return $htresponse->finalize;
    };

    return $nyaaa;
}

sub req {
    my $self = shift;
    return $self->request;
}

sub res {
    my $self = shift;
    return $self->response;
}

sub rdr {
    my $self = shift;
    my $next = shift;
    my $code = shift || 302;

    $self->response->redirect( $next, $code );
    return $self->response;
}

sub err {
    my $self = shift;
    my $code = shift || 404;
    my $mesg = shift || 'Not found';

    $self->response->code( $code );
    $self->response->content_type( 'text/plain' );
    $self->response->content_length( length $mesg );
    $self->response->body( $mesg );
    return $self->response;
}

sub r {
    my $self = shift;
    my $neko = $self->router->routematch( $self->req->env );
    return $self->err unless $neko;

    my $ctrl = sprintf( "Haineko::%s", $neko->dest->{'controller'} );
    my $subr = $neko->dest->{'action'};
    my $e500 = 0;

    try {
        require Module::Load;
        Module::Load::load( $ctrl );

    } catch {
        $e500 = 1;
    };

    return $ctrl->$subr( $self ) unless $e500;
    return $self->err( 500, 'Internal Server Error' );
}

1;
