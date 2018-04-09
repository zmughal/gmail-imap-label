#!/usr/bin/perl

use Test::More;
use Capture::Tiny qw/capture_stdout/;

BEGIN { use_ok( 'Net::Gmail::IMAP::Label' ); }
require_ok( 'Net::Gmail::IMAP::Label' );

# test --help
@ARGV = qw/-h/;
my $usage_msg = capture_stdout { Net::Gmail::IMAP::Label->run  };

like($usage_msg, qr/--help/, 'has --help option');
like($usage_msg, qr/--port/, 'has --port option');
like($usage_msg, qr/--verbose/, 'has --verbose option');

done_testing;
