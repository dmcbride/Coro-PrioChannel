package Coro::PrioChannel::Multi;
use strict;
use warnings;

# ABSTRACT: Multiple-listener priority message queues for Coro

=head1 SYNOPSIS

    use Coro::PrioChannel::Multi;

    my $q = Coro::PrioChannel::Multi->new($maxsize);
    $q->put("xxx"[, $prio]);

    my $l = $q->listen();
    print $l->get; # from Coro::PrioChannel

=head1 DESCRIPTION

A Coro::PrioChannel::Multi is exactly like L<Coro::PrioChannel>, but with
the ability to add (and lose) listeners.

Unlike Coro::Channel, you do have to load this module directly.

Each item that is put into the channel will get sent to all listener(s).
However, there is no deep copy here, if the item put in is a reference,
all listeners will receive a reference to the same object, which will allow
each listening thread to modify it before the next thread sees it.  This
could be construed as a feature.

Messages put into the channel before any listener is set up will be lost.
Messages put into the channel before a listener is set up will not be 
resent to that listener, even if the message is still in some other listener's
channel.

=head1 METHODS

=over 4

=cut

use Coro::PrioChannel;
use Scalar::Util qw(weaken);

=item new

Create a new channel with the given maximum size.  Giving a size of one
defeats the purpose of a priority queue.  However, with multiple listeners,
this should ensure that each listener deals with the item before we add
the next item.

=cut

sub new
{
    my $class = shift;
    my $self  = bless [], $class;

    $self;
}

=item clean

Clears out any channels that have gone away.  Shouldn't normally be needed
as the object will generally self-clean.

The concept is that a listener may no longer be interested, and has let
its channel listener go out of scope, which will leave a hole in the
list of listeners.  This method simply clears out the holes.

=cut

sub clean
{
    my $self = shift;
    @$self = grep { defined } @$self;

    # when we pull out the refs this way, they're
    # no longer weakened, so re-weaking everything.
    # (easier than using splice to pull undef items out -
    #  if we get too many readers, we'll re-evaluate if this
    #  is slow.)
    weaken($_) for @$self;
}

=item number_of_listeners

Returns a count of the number of listeners still attached to this
channel.

=cut

sub number_of_listeners
{
    my $self = shift;
    $self->clean();
    scalar @$self;
}

# debugging aid.
sub _status
{
    my $self = shift;
    $self->clean();
    'Channel=size :: ' . join ":", map { $_ . "=" . $self->[$_]->size() } 0..$#$self;
}

=item listen

Set up a new listener for the channel.  Returns a Coro::PrioChannel object
that you issue a C<-E<gt>get> against.  For example:

    my $l = $cpcm->listen();
    while (my $item = $l->get())
    {
        #...
    }

=cut

# create new channel, add it to $self, ensure it's weakened, and return
# the non-weak version.
sub listen
{
    my $self = shift;
    my $channel = Coro::PrioChannel->new();
    push @$self, $channel;

    $self->clean();

    $channel;
}

=item put

Pass a message to all (current) listeners.  Optionally provide a priority
between L<Coro>::PRIO_MIN and L<Coro>::PRIO_MAX.

=cut

sub put
{
    my $self = shift;

    $self->clean();

    # if we were really multi-threaded, we'd still
    # have to check if $_ was defined, but Coro eliminates
    # that possibility since nothing else really runs between
    # the clean() above and this (we don't cede)
    $_->put(@_) for (@$self);
}

1;
