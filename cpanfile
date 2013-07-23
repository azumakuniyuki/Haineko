requires 'perl', '5.010001';
requires 'Authen::SASL', '2.16';
requires 'Class::Accessor::Lite', '0.05';
requires 'Email::MIME', '1.910';
requires 'Encode', '2.42';
requires 'IO::Socket::SSL', '1.94';
requires 'Furl', '2.17';
requires 'JSON::Syck', '1.18';
requires 'Module::Load', '0.18';
requires 'Mojolicious', '3.89';
requires 'Net::SMTP', '2.31';
requires 'Net::SMTPS', '0.03';
requires 'Net::CIDR::Lite', '0.21';
requires 'Path::Class', '0.24';
requires 'Sys::Syslog', '0.33';
requires 'Time::Piece', '1.20';

on test => sub {
	requires 'Test::More', '0.98';
};

on develop => sub {
	requires 'Test::UsedModules', '0.03';
};
