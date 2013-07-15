package Haineko::Data;
use strict;
use warnings;
use DBI;

sub databases { return [ 'postgresql', 'mysql', 'sqlite' ] }
sub dbpresets {
	return {
		'postgresql' => {
			'dbtype' => 'PostgreSQL',
			'dbport' => 5432,
			'driver' => 'Pg',
			'dbname' => 'dbname',
			'socket' => 'host',
			'unicode'=> 'pg_enable_utf8',
		},
		'mysql' => {
			'dbtype' => 'MySQL',
			'dbport' => 3306,
			'driver' => 'mysql',
			'dbname' => 'database',
			'socket' => 'mysql_socket',
			'unicode'=> 'mysql_enable_utf8',
		},
		'sqlite' => {
			'dbtype' => 'SQLite',
			'dbport' => q(),
			'driver' => 'SQLite',
			'dbname' => 'dbname',
			'socket' => q(),
			'unicode'=> 'sqlite_unicode',
		},
	};
}

sub new
{
	my $class = shift;
	my $argvs = { @_ };

	$argvs->{'error'} = { 'string' => q(), 'count' => 0 };
	$argvs->{'autocommit'} //= 1;
	$argvs->{'raiseerror'} //= 1;
	$argvs->{'printerror'} //= 0;
	$argvs->{'useunicode'} //= 1;
	return bless $argvs, __PACKAGE__;
}

sub setup
{
	my $self = shift;
	my $conf = shift || return $self;

	return $self unless ref $conf eq 'HASH';
	my $supportdbs = __PACKAGE__->databases;
	my $presetting = __PACKAGE__->dbpresets;

	$self->{'dbtype'}   ||= $conf->{'dbtype'}   || $presetting->{'sqlite'}->{'dbtype'};
	$self->{'dbname'}   ||= $conf->{'dbname'}   || ':memory:';
	$self->{'host'}     ||= $conf->{'host'}     || 'localhost';
	$self->{'port'}     ||= $conf->{'port'}     || q();
	$self->{'username'} ||= $conf->{'username'} || q();
	$self->{'password'} ||= $conf->{'password'} || q();

	# Unsupported database
	return undef unless( grep { lc $self->{'dbtype'} eq $_ } @$supportdbs );

	my $dbtype = lc $self->{'dbtype'};
	my $dbhost = $self->{'host'};
	my $whatdb = ( $dbtype =~ m{(?>(?:postgre(?>(?:s|sql))|pgsql))} ) ? 'postgresql' : lc $dbtype;
	my $dbport = $self->{'port'} || ( ( $dbhost ne 'localhost' ) ? $presetting->{ $whatdb }->{'dbport'} : q() );
	my $dsname = q();

	if( $whatdb eq 'sqlite' )
	{
		$dsname = sprintf( "dbi:SQLite:dbname=%s", $self->{'dbname'} );
		$self->{'username'} = q();
		$self->{'password'} = q();
		$self->{'host'} = q();
		$self->{'port'} = q();
	}
	else
	{
		if( $dbhost eq 'localhost' )
		{
			# Use UNIX domain socket
			#  Postgresql: dbi:Pg:dbname=name;host=/path/to/socket/dir;"
			#  MySQL: dbi:mysql:database=name;mysql_socket=/path/to/socket;
			#
			$dsname = sprintf( "dbi:%s:%s=%s;%s=%s", $presetting->{ $whatdb }->{'driver'},
					$presetting->{ $whatdb }->{'dbname'}, $self->{'dbname'},
					$presetting->{ $whatdb }->{'socket'}, $dbport );
			$self->{'port'} = q();
			$self->{'host'} = 'localhost';
		}
		else
		{
			# Use TCP/IP connection
			$dbport = $presetting->{ $whatdb }->{'dbport'} unless( $dbport =~ m{\A\d+\z} );
			$dsname = sprintf( "dbi:%s:%s=%s;host=%s;port=%d", 
					$presetting->{ $whatdb }->{'driver'},
					$presetting->{ $whatdb }->{'dbname'}, $self->{'dbname'}, 
					$dbhost, $dbport );
			$self->{'port'} = $dbport;
		}
	}

	$self->{'dbtype'} = $presetting->{ $whatdb }->{'dbtype'};
	$self->{'dsname'} = $dsname;

	return $self;
}

sub connect
{
	my $self = shift;

	my $datasource = $self->{'dsname'};
	my $methodargv = [];
	my $dbioptions = {};
	my $presetting = __PACKAGE__->dbpresets;
	my $unicodekey = $presetting->{ lc $self->{'dbtype'} }->{'unicode'};

	eval { 
		$dbioptions = {
			'AutoInactiveDestroy' => 1,
			'AutoCommit' => $self->{'autocommit'},
			'RaiseError' => $self->{'raiseerror'},
			'PrintError' => $self->{'printerror'},
		};

		$dbioptions->{ $unicodekey } = 1 if $self->{'useunicode'};
		$methodargv = [ $datasource, $self->{'username'}, $self->{'password'}, $dbioptions ];
		$self->{'handle'} = DBI->connect( @$methodargv );
	};
	$self->{'connected'} = time;
	return $self->{'handle'} unless $@;

	$self->{'error'}->{'string'} = $@;
	$self->{'error'}->{'count'}++;
	return undef;
}

sub disconnect
{
	my $self = shift;
	my $conn = $self->{'handle'} || return 0;

	eval { 
		$conn->disconnect;
		$self->{'handle'} = undef;
	};

	return 1 unless $@;
	$self->{'error'}->{'string'} = $@;
	$self->{'error'}->{'count'}++;
	return 0;
}

sub DESTROY
{
	my $self = shift;
	return $self->disconnect;
}

1;
__END__
