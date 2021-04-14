package inc::ZMQ4::SocketWrappers;

use Moo;
use namespace::clean;

extends 'inc::ZMQ3::SocketWrappers';

sub socket_monitor_tt {q(
sub socket_monitor {
    my ($self, $endpoint, $events) = @_;

    [% closed_socket_check %]

    unless ($endpoint) {
        croak 'usage: $socket->socket_monitor($endpoint, $events)';
    }
    
    unless ($events) {
        $events = ZMQ_EVENT_ALL;
    }

    $self->check_error(
        'zmq_socket_monitor',
        zmq_socket_monitor($self->socket_ptr, $endpoint, $events)
    );
}
)}

1;
