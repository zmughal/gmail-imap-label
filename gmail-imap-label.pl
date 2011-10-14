#!/usr/bin/perl
use warnings;
use strict;
use POE qw(Component::Server::TCP Component::Client::TCP);


# Spawn the forwarder server on port 1110.  When new connections
# arrive, spawn clients to connect them to their destination.
POE::Component::Server::TCP->new(
  Port            => 1110,
  ClientConnected => sub {
    my ($heap, $session) = @_[HEAP, SESSION];
    logevent('server got connection', $session);
    spawn_client_side();
  },
  ClientInput => sub {
    my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
    logevent('server got input', $session, $input);
    $kernel->post($heap->{client_id} => send_stuff => $input);
  },
  ClientDisconnected => sub {
    my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
    logevent('server got disconnect', $session);
    $kernel->post($heap->{client_id} => "shutdown");
  },
  InlineStates => {
    send_stuff => sub {
      my ($heap, $stuff) = @_[HEAP, ARG0];
      logevent("sending to server", $_[SESSION]);
      $heap->{client}->put($stuff);
    },
    _child => sub {
      my ($heap, $child_op, $child) = @_[HEAP, ARG0, ARG1];
      if ($child_op eq "create") {
        $heap->{client_id} = $child->ID;
      }
    },
  },
);

sub spawn_client_side {
  POE::Component::Client::TCP->new(
    RemoteAddress => 'localhost',
    RemotePort    => 6667,
    Started       => sub {
      $_[HEAP]->{server_id} = $_[SENDER]->ID;
    },
    Connected => sub {
      my ($heap, $session) = @_[HEAP, SESSION];
      logevent('client connected', $session);
    },
    ServerInput => sub {
      my ($kernel, $heap, $session, $input) = @_[KERNEL, HEAP, SESSION, ARG0];
      logevent('client got input', $session, $input);
      $kernel->post($heap->{server_id} => send_stuff => $input);
    },
    Disconnected => sub {
      my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
      logevent('client disconnected', $session);
      $kernel->post($heap->{server_id} => 'shutdown');
    },
    InlineStates => {
      send_stuff => sub {
        my ($heap, $stuff) = @_[HEAP, ARG0];
        logevent("sending to client", $_[SESSION]);
        $heap->{server}->put($stuff);
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
