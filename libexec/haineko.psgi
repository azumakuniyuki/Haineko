#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
BEGIN { 
    unshift @INC, "$FindBin::Bin/../lib";
}

use Haineko;
Haineko->start;
