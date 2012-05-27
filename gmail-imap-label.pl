#!/usr/bin/env perl
use warnings;
use strict;
use POE qw(Component::Server::TCP Component::Client::TCP
	Filter::Stackable Filter::Map);
use POE::Component::SSLify qw( Client_SSLify );
use Regexp::Common;
use Encode::IMAPUTF7;
use Encode qw/decode encode_utf8/;

use constant LOCALPORT => 10143;

# Spawn the forwarder server on port LOCALPORT.  When new connections
# arrive, spawn clients to connect them to their destination.
POE::Component::Server::TCP->new(
	Port            => LOCALPORT,
	ClientConnected => sub {
		my ($heap, $session) = @_[HEAP, SESSION];
		#logevent('server got connection', $session);
		$heap->{client_id} = spawn_client_side();
	},
	ClientFilter => POE::Filter::Stackable->new(
		Filters => [
			POE::Filter::Line->new( Literal => "\x0D\x0A"),
			POE::Filter::Map->new(
				Get => sub {
					my $data = shift;
					if($data =~ /^\w+ FETCH/) {
						$data =~ s,(BODY\.PEEK\[[^\]]*\]),$1 X-GM-LABELS,;
					} elsif($data =~ /^\w+ UID FETCH (\d+) \(?BODY.PEEK\[\]\)?$/) {
						$data =~ s,\(?(BODY.PEEK\[\])\)?,($1 X-GM-LABELS),;
					}
					return $data;
			},
				Put => sub {
					my $data = shift;
					my $fetch_re = qr/^\* \d+ FETCH.*{\d+}$/;
					my $fetch_gm_label = qr/^(\* \d+ FETCH.*)(X-GM-LABELS $RE{balanced}{-parens=>'()'} ?)(.*){(\d+)}$/;
					if( $data =~ $fetch_gm_label ) {
						my $octets = $4;
						my $new_fetch = "$1$3";
						#print "$new_fetch\n";
						(my $x_label = $2) =~ /\((.*)\)/;
						$x_label = $1;
						$x_label =~ s,"\\\\Important"\s*,,;
						$x_label =~ s,"\\\\Sent"\s*,,;
						$x_label =~ s,"\\\\Starred"\s*,,;
						$x_label =~ s,"\\\\Inbox",INBOX,;
						# Gmail sends IMAP's modified UTF-7,
						# need to convert to UTF-8 to satisfy
						# <http://tools.ietf.org/html/rfc5738> in mutt
						$x_label = decode('IMAP-UTF-7', $x_label);
						if(length($x_label) > 0) {
							$x_label = "X-Label: $x_label";
							#print "$x_label\n";
							$octets += length(encode_utf8($x_label))+2; # 2 more for line separator
							$new_fetch .= "{$octets}";
							$new_fetch .= "\x0D\x0A";
							$new_fetch .= $x_label;
						} else {
							$new_fetch .= "{$octets}";
						}
						return $new_fetch;
					}
					return $data;
		}),
	]),
	ClientInput => sub {
		my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
		#logevent('server got input', $session, $input);
		$kernel->post($heap->{client_id} => send_stuff => $input);
	},
	ClientDisconnected => sub {
		my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
		#logevent('server got disconnect', $session);
		$kernel->post($heap->{client_id} => "shutdown");
	},
	InlineStates => {
		send_stuff => sub {
			my ($heap, $stuff) = @_[HEAP, ARG0];
			#logevent("sending to server", $_[SESSION]
				#, $stuff
			#);
			eval { $heap->{client}->put($stuff); };
		},
	},
);

sub spawn_client_side {
	POE::Component::Client::TCP->new(
		RemoteAddress => 'imap.gmail.com',
		PreConnect => sub {
			# Convert the socket into an SSL socket.
			my $socket = eval { Client_SSLify($_[ARG0]) };
			return if $@; # Disconnect if SSL failed.
			return $socket;
		},
		RemotePort    => 993,
		Filter        => POE::Filter::Line->new( Literal => "\x0D\x0A" ),
		Started       => sub {
			$_[HEAP]->{server_id} = $_[SENDER]->ID;
		},
		Connected => sub {
			my ($heap, $session) = @_[HEAP, SESSION];
			#logevent('client connected', $session);
			eval { $heap->{server}->put(''); };
		},
		ServerInput => sub {
			my ($kernel, $heap, $session, $input) = @_[KERNEL, HEAP, SESSION, ARG0];
			#logevent('client got input', $session, $input);
			# TODO: check capabilities?
			$kernel->post($heap->{server_id} => send_stuff => $input);
		},
		Disconnected => sub {
			my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
			#logevent('client disconnected', $session);
			$kernel->post($heap->{server_id} => 'shutdown');
		},
		ConnectError => sub {
			my ($operation, $error_number, $error_string) = @_[ARG0..ARG2];
			my $id = $_[SESSION]->ID;
			print STDERR "Client $id: $operation error $error_number occurred: $error_string\n";
			$_[KERNEL]->post($_[HEAP]->{server_id} => 'shutdown');
		},
		InlineStates => {
			send_stuff => sub {
				my ($heap, $stuff) = @_[HEAP, ARG0];
				#logevent("sending to client", $_[SESSION]);
				eval { $heap->{server}->put($stuff); };
			},
		},
	);
}

sub logevent {
	my ($state, $session, $arg) = @_;
	my $id = $session->ID();
	print "session $id $state ";
	print ": $arg" if (defined $arg);
	print "\n";
}
warn 'running';
$poe_kernel->run();
exit 0;

# vim:ts=4:sw=4
