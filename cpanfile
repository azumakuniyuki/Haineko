requires 'perl', '5.010';
requires 'Archive::Tar', '1.76';
requires 'Authen::SASL', '2.16';
requires 'Class::Accessor::Lite', '0.05';
requires 'Crypt::SaltedHash', '0.05';
requires 'Digest::SHA', '5.61';
requires 'Email::MIME', '1.910';
requires 'Encode', '2.42';
requires 'File::Basename', '2.82';
requires 'File::Copy', '2.21';
requires 'File::Temp', '0.22';
requires 'Furl', '2.17';
requires 'Getopt::Long', '2.39';
requires 'IO::File', '1.15';
requires 'IO::Socket::SSL', '1.94';
requires 'JSON::Syck', '1.18';
requires 'MIME::Base64', '3.13';
requires 'Module::Load', '0.18';
requires 'Net::SMTP', '2.31';
requires 'Net::SMTPS', '0.03';
requires 'Net::CIDR::Lite', '0.21';
requires 'Path::Class', '0.24';
requires 'Plack', '1.0027';
requires 'Plack::Middleware::Auth::Basic', '';
requires 'Router::Simple', '0.14';
requires 'Server::Starter', '0.15';
requires 'Sys::Syslog', '0.33';
requires 'Try::Tiny', '0.16';
requires 'Time::Piece', '1.20';
requires 'XML::Simple', '2.20';

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Plack::Test', '';
    requires 'HTTP::Request', '6.00';
};

on develop => sub {
    requires 'Test::UsedModules', '0.03';
    requires 'IO::Socket::INET', '1.31';
};
