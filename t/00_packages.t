#!/usr/bin/perl

use Test::More;

BEGIN { use_ok( 'Net::Gmail::IMAP::Label' ); }
require_ok( 'Net::Gmail::IMAP::Label' );

BEGIN { use_ok( 'Net::Gmail::IMAP::Label::Proxy' ); }
require_ok( 'Net::Gmail::IMAP::Label::Proxy' );

done_testing;
