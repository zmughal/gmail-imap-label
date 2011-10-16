#!/usr/bin/perl
use warnings;
use strict;
use POE qw(Component::Server::TCP Component::Client::TCP Filter::SSL);


# Spawn the forwarder server on port 10143.  When new connections
# arrive, spawn clients to connect them to their destination.
POE::Component::Server::TCP->new(
  Port            => 10143,
  ClientConnected => sub {
    my ($heap, $session) = @_[HEAP, SESSION];
    logevent('server got connection', $session);
    $heap->{client_id} = spawn_client_side();
  },
  ClientFilter => [ "POE::Filter::Line", Literal => "\x0D\x0A" ],
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
  },
);

sub spawn_client_side {
  POE::Component::Client::TCP->new(
    RemoteAddress => 'imap.gmail.com',
    RemotePort    => 993,
    Filter        => POE::Filter::Stackable->new(
        Filters => [
            POE::Filter::SSL->new( client => 1 ),
            POE::Filter::Line->new( Literal => "\x0D\x0A" ),
    ]),
    Started       => sub {
      $_[HEAP]->{server_id} = $_[SENDER]->ID;
    },
    Connected => sub {
      my ($heap, $session) = @_[HEAP, SESSION];
      logevent('client connected', $session);
      $heap->{server}->put('');
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
  #print ": $arg" if (defined $arg);
  print "\n";
}
warn 'running';
$poe_kernel->run();
exit 0;
