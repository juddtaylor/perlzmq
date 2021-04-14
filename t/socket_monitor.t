use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::Exception;

use ZMQ::FFI;
use ZMQ::FFI::Constants qw( 
        ZMQ_DEALER ZMQ_PAIR 
        ZMQ_EVENT_ALL 
        ZMQ_EVENT_CONNECTED ZMQ_EVENT_CONNECT_DELAYED ZMQ_EVENT_LISTENING ZMQ_EVENT_ACCEPTED ZMQ_EVENT_CLOSED ZMQ_EVENT_MONITOR_STOPPED
    );

my $c = ZMQ::FFI->new();

my ($major, $minor) = $c->version();


if( $major == 4 ) {
    
    # Monitor these 2 sockets:
    my $client = $c->socket( ZMQ_DEALER );
    ok( $client, 'create client socket');
    $client->die_on_error(0);
    
    my $server = $c->socket( ZMQ_DEALER );
    ok( $server, 'create server socket');
    $server->die_on_error(0);
    
    my $rc;
    # Socket monitoring only works over inproc:
    $client->socket_monitor("tcp://127.0.0.1:9999", 0);
    ok( $client->has_error, "create invalid socket_monitor endpoint");
    is( $client->last_strerror, "Protocol not supported" );
    
    # Monitor all events on client and server sockets:
    $client->socket_monitor( 'inproc://monitor-client', ZMQ_EVENT_ALL );
    ok( !$client->has_error, "create client socket_monitor" );
    $rc = $server->socket_monitor( 'inproc://monitor-server', ZMQ_EVENT_ALL );
    ok( !$server->has_error, "create server socket_monitor" );
    
    # Create two sockets for collecting monitor events:
    my $client_mon = $c->socket( ZMQ_PAIR );
    ok( $client_mon, "create client mon socket" );
    my $server_mon = $c->socket( ZMQ_PAIR );
    ok( $server_mon, "create server mon socket" );
    
    # Connect these to the inproc endpoints so they'll get events:
    $client_mon->connect( 'inproc://monitor-client' );
    ok( !$client_mon->has_error, "client mon connected" );
    $rc = $server_mon->connect( 'inproc://monitor-server' );
    ok( !$server_mon->has_error, "server mon connected" );
    
    # Now do a basic ping test:
    $server->bind( "tcp://127.0.0.1:9998" );
    ok( !$server->has_error, "server bind" );
    $client->connect( "tcp://127.0.0.1:9998" );
    ok( !$client->has_error, "client connect" );
    
    #bounce( $client, $server ); #?
    my $msg = "ohai";
    $server->send( $msg );
    ok( !$server->has_error, "server send" );
    is( $client->recv, $msg, "client recv" );
    
    # Close the client and the server:
    $client->close;
    $server->close;
    
    # Now collect and check events from both sockets:
    
    # Client events:
    my $event = get_monitor_event( $client_mon );
    $event = get_monitor_event( $client_mon )
        if( $event == ZMQ_EVENT_CONNECT_DELAYED );
    is( $event, ZMQ_EVENT_CONNECTED );
    
    $event = get_monitor_event( $client_mon );
    is( $event, ZMQ_EVENT_MONITOR_STOPPED );
    
    # Server events:
    $event = get_monitor_event( $server_mon );
    is( $event, ZMQ_EVENT_LISTENING );
    
    $event = get_monitor_event( $server_mon );
    is( $event, ZMQ_EVENT_ACCEPTED );
    
    $event = get_monitor_event( $server_mon );
    is( $event, ZMQ_EVENT_CLOSED );
    
    $event = get_monitor_event( $server_mon );
    is( $event, ZMQ_EVENT_MONITOR_STOPPED );
    
    # Close down the sockets:
    $client_mon->close;
    $server_mon->close;
    
    ok(0); # This just prevents the tests from succeeding for now.
    
    
} 
else {
    my $s = $c->socket(ZMQ_DEALER);
    
    # zmq < 4.x - socket_monitor not implemented.
    throws_ok { $s->socket_monitor() }
                qr'socket_monitor not available',
                'threw unimplemented error in < 4.x'; #>'
}

done_testing;


sub get_monitor_event
{
    my $mon = shift;

    print STDERR "\$mon = " . (ref($mon)) . "\n";
    print STDERR "About to \$mon->recv()\n";
    
    my $data = $mon->recv( 0 );
    
    print STDERR "Done \$mon->recv()\n";

    print STDERR "\$data(" . length($data) . ") = " . sprintf("%*v02x", "", $data ) . "\n";
    
    return 1;
}
