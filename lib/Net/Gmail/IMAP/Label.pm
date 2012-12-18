package Net::Gmail::IMAP::Label;

use strict;
use warnings;
use Net::Gmail::IMAP::Label::Proxy;
use Getopt::Long::Descriptive;

sub import {
	my ($class, @opts) = @_;
	return unless (@opts == 1 && $opts[0] eq 'run');
	$class->run;
}

sub run {
	my ($opts, $usage) = describe_options(
	  "$0 %o",
	  [ 'port|p=i',   "local port to connect to (default: @{[Net::Gmail::IMAP::Label::Proxy::DEFAULT_LOCALPORT]})", { default => Net::Gmail::IMAP::Label::Proxy::DEFAULT_LOCALPORT } ],
	  [ 'verbose|v+',  "increase verbosity (multiple flags for more verbosity)" , { default => 0 } ],
	  [ 'help|h|?',       "print usage message and exit" ],
	);

	if($opts->help) {
		print($usage->text);
		return 1;
	}

	Net::Gmail::IMAP::Label::Proxy->new(localport => $opts->port, verbose => $opts->verbose)->run();
}

1;

=head1 NAME

Net::Gmail::IMAP::Label - IMAP proxy for Google's Gmail that retrieves message labels

=head1 SYNOPSIS

gmail-imap-label [OPTION]...

=head1 DESCRIPTION

This module provides a proxy that sits between an IMAP client and Gmail's IMAPS
server and adds GMail labels to the X-Label header. This proxy uses the
L<Gmail IMAP extensions|http://code.google.com/apis/gmail/imap/#x-gm-labels>.

To use this proxy, your e-mail client will need to connect to the proxy using
the IMAP protocol (without SSL).

=head1 EXAMPLES

The simplest way of starting is to run the proxy on the default port of 10143:

    gmail-imap-label

An alternative port can be specified using the B<--port> option

    gmail-imap-label --port 993

The proxy has been tested with both mutt (v1.5.21) and offlineimap (v6.3.4).
Example configuration files for these are available in the C<doc> directory.

=head1 SEE ALSO

See L<gmail-imap-label> for a complete listing of options.

=head1 BUGS

Report bugs and submit patches to the repository on L<Github|https://github.com/zmughal/gmail-imap-label>.

=head1 COPYRIGHT

Copyright 2011 Zakariyya Mughal.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the ISC license, or

=item * the Artistic License version 2.0.

=back

=head1 ACKNOWLEDGMENTS

Thanks to L<Paul DeCarlo|http://windotnet.blogspot.com/> for pointing out the
Gmail IMAP extensions.

=cut

# vim:ts=4:sw=4
