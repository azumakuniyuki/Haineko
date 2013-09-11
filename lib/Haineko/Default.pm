package Haineko::Default;
use strict;
use warnings;

sub conf {
    return {
        'smtpd' => { 
            'auth' => 0,                    # No authentication
            'hostname' => '',               # used at EHLO
            'max_message_size' => 4194304,  # 4KB
            'max_rcpts_per_message' => 4,   # 4 recipients
            'milter' => {
                'libs' => [],
            },
            'syslog' => {
                'disabled' => 1,
                'facility' => 'local2',
            },
        },
    };
}

sub table {
    my $class = shift;
    my $argvs = shift || return [];
    my $table = {
        'mailer' => {
            'mail' => 'sendermt',
            'auth' => 'authinfo',
            'rcpt' => 'mailertable',
        },
        'access' => {
            'conn' => 'relayhosts',
            'rcpt' => 'recipients',
        },
    };

    return $table->{ $argvs };
}

1;
