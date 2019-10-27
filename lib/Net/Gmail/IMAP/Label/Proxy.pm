package Net::Gmail::IMAP::Label::Proxy;
# ABSTRACT: Implementation of proxy logic for FETCH X-GM-LABELS

use warnings;
use strict;
use POE qw(Component::Server::TCP Component::Client::TCP
	Filter::Stackable Filter::Map);
use POE::Component::SSLify qw( Client_SSLify );
use Regexp::Common;
use Encode::IMAPUTF7;
use Encode qw/decode encode_utf8/;
use Carp;

use constant DEFAULT_LOCALPORT => 10143;
use constant LINESEP => "\x0D\x0A";
use constant GMAIL_HOST => 'imap.gmail.com';
use constant GMAIL_PORT => 993; # IMAPS port

# options
#   * localport : (0..65535) - port to start local side of proxy
#   * verbose   : (0..4)     - logging level
sub new {
	my $class = shift;
	ref($class) and croak "class name needed";
	my %opts = @_;
	my $self = {};
	bless $self, $class;
	$self->{verbose} = $opts{verbose} // 0;
	$self->{localport} = $opts{localport} // DEFAULT_LOCALPORT;
	$self;
}

sub run {
	my ($self) = @_;
	$self->init() unless $self->{_init};
	$self->{verbose} and carp 'running';
	$poe_kernel->run();
}

# Spawn the forwarder server on port given in by localport option.  When new
# connections arrive, spawn clients to connect them to their destination.
sub init {
	my ($self) = @_;
	POE::Component::Server::TCP->new(
		Port            => $self->{localport},
		ClientConnected => sub {
			my ($heap, $session) = @_[HEAP, SESSION];
			$self->{verbose} > 0 and logevent('server got connection', $session);
			$heap->{client_id} = $self->spawn_client_side();
		},
		ClientFilter => POE::Filter::Stackable->new(
			Filters => [
				POE::Filter::Line->new( Literal => LINESEP),
				POE::Filter::Map->new( Get => \&get_label, Put => \&put_label ),
		]),
		ClientInput => sub {
			my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
			$self->{verbose} > 2 and logevent('server got input', $session, $self->{verbose} > 3 ? $input : undef);
			$kernel->post($heap->{client_id} => send_stuff => $input);
		},
		ClientDisconnected => sub {
			my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
			$self->{verbose} > 0 and logevent('server got disconnect', $session);
			$kernel->post($heap->{client_id} => "shutdown");
		},
		InlineStates => {
			send_stuff => sub {
				my ($heap, $stuff) = @_[HEAP, ARG0];
				$self->{verbose} > 2 and logevent("sending to server", $_[SESSION], $self->{verbose} > 3 ? $stuff : undef );
				eval { $heap->{client}->put($stuff); };
			},
		},
	);
	$self->{_init} = 1; # set init flag
}

sub spawn_client_side {
	my ($self) = @_;
	POE::Component::Client::TCP->new(
		RemoteAddress => GMAIL_HOST,
		PreConnect => sub {
			# Convert the socket into an SSL socket.
			my $socket = eval { Client_SSLify($_[ARG0]) };
			return if $@; # Disconnect if SSL failed.
			return $socket;
		},
		RemotePort    => GMAIL_PORT, # IMAPS port
		Filter        => POE::Filter::Line->new( Literal => LINESEP),
		Started       => sub {
			$_[HEAP]->{server_id} = $_[SENDER]->ID;
		},
		Connected => sub {
			my ($heap, $session) = @_[HEAP, SESSION];
			$self->{verbose} > 0 and logevent('client connected', $session);
			eval { $heap->{server}->put(''); };
		},
		ServerInput => sub {
			my ($kernel, $heap, $session, $input) = @_[KERNEL, HEAP, SESSION, ARG0];
			$self->{verbose} > 1 and logevent('client got input', $session, $self->{verbose} > 2 ? $input : undef);
			# TODO: check capabilities?
			$kernel->post($heap->{server_id} => send_stuff => $input);
		},
		Disconnected => sub {
			my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
			$self->{verbose} > 0 and logevent('client disconnected', $session);
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
				$self->{verbose} > 2 and logevent("sending to client", $_[SESSION], $self->{verbose} > 3 ? $stuff : undef);
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

sub get_label {
	my $data = shift;
	if($data =~ /^\w+ FETCH/) {
		$data =~ s,(BODY\.PEEK\[[^\]]*\]),$1 X-GM-LABELS,;
	} elsif($data =~ /^\w+ UID FETCH (\d+) \(?BODY.PEEK\[\]\)?$/) {
		$data =~ s,\(?(BODY.PEEK\[\])\)?,($1 X-GM-LABELS),;
	}
	return $data;
}

sub put_label {
	my $data = shift;
	my $label_re = qr/(?:[^() "]+)|$RE{delimited}{-delim=>'"'}/;
	my $fetch_gm_label = qr/^(\* \d+ FETCH.*)(X-GM-LABELS \((?:(?:$label_re\s+)*$label_re)?\) ?)(.*)\{(\d+)\}$/;
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
		$x_label =~ s,^\s+,,; $x_label =~ s,\s+$,,; # trim
		# Gmail sends IMAP's modified UTF-7,
		# need to convert to UTF-8 to satisfy
		# <http://tools.ietf.org/html/rfc5738> in mutt
		$x_label = decode('IMAP-UTF-7', $x_label);
		if(length($x_label) > 0) {
			$x_label = "X-Label: $x_label";
			#print "$x_label\n";
			$octets += length(encode_utf8($x_label))+length(LINESEP); # 2 more for line separator
			$new_fetch .= "{$octets}";
			$new_fetch .= LINESEP;
			$new_fetch .= $x_label;
		} else {
			$new_fetch .= "{$octets}";
		}
		return $new_fetch;
	}
	return $data;
}

1;

# vim:ts=4:sw=4
