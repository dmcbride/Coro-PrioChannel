package Coro::PrioChannel;
use strict;
use warnings;

# ABSTRACT: Priority message queues for Coro

=head1 SYNOPSIS

    use Coro::PrioChannel;

    my $q = Coro::PrioChannel->new($maxsize);
    $q->put("xxx"[, $prio]);

    print $q->get;

=head1 DESCRIPTION

A Coro::PrioChannel is exactly like L<Coro::Channel>, but with priorities.
The priorities are the same as for L<Coro> itself.

Unlike Coro::Channel, you do have to load this module directly.

=head1 METHODS

=over 4

=cut

use Coro qw(:prio);
use Coro::Semaphore ();

use List::Util qw(first sum);
use Time::HiRes qw(time);

sub SGET()      { 0 }
sub SPUT()      { 1 }
sub REPRIO()    { 2 }
sub NEXTCHECK() { 3 }
sub DATA()      { 4 }
sub MAX()       { PRIO_MAX - PRIO_MIN + DATA + 1 }

=item new

Create a new channel with the given maximum size.  Giving a size of one
defeats the purpose of a priority queue.  Optionally specify the amount of
time spent in the queue before an item's priority is boosted to avoid
starvation.

=cut

sub new {
   # we cheat, just like Coro::Channel.
   bless [
      (Coro::Semaphore::_alloc 0), # counts data
      (Coro::Semaphore::_alloc +($_[1] || 2_000_000_000) - 1), # counts remaining space
      $_[2], # reprioritization check time
      (defined $_[2] ? (time + $_[2]) : undef), # last reprioritization check
      [], # initially empty
   ]
}

=item put

Put the given scalar into the queue.  Optionally provide a priority between
L<Coro>::PRIO_MIN and L<Coro>::PRIO_MAX.

=cut

sub _put {
   my $after = (time + $_[0]->[REPRIO]) if defined $_[0]->[REPRIO];
   push @{$_[0][DATA + ($_[2]||PRIO_NORMAL) - PRIO_MIN()]}, [$_[1], $after];
}

sub put {
   $_[0]->reprioritize;
   _put @_;
   Coro::Semaphore::up   $_[0][SGET];
   Coro::Semaphore::down $_[0][SPUT];
}

=item get

Return the next element from the queue at the highest priority, waiting if
necessary.

TODO: allow an optional parameter to wait for a message of a minimum priority
level (i.e., ignore messages of lower priority).

=cut

sub get {
   Coro::Semaphore::down $_[0][SGET];
   Coro::Semaphore::up   $_[0][SPUT];

   my $a = first { $_ && scalar @$_ } reverse @{$_[0]}[DATA..MAX];

   ref $a ? shift(@$a)->[0] : undef;
}

=item reprioritize

Reprioritizes the queue, boosting the priority of elements that have been in
the queue for longer than the reprioritization parameter (passed to the
constructor). This method is called automatically by put() and should not need
to be called directly in normal circumstances.

=cut

sub reprioritize {
    return unless defined $_[0]->[REPRIO];

    my $now = time;
    return unless $_[0]->[NEXTCHECK] <= $now;

    my $q = $_[0];
    foreach my $pri (PRIO_MIN .. PRIO_HIGH) {
        my $next_pri = $pri + 1;
        my $idx      = DATA + $pri - PRIO_MIN;
        my @keep;

        foreach my $item (@{$q->[$idx]}) {
            if ($item->[1] <= $now) {
                _put $q, $item->[0], $next_pri;
            } else {
                push @keep, $item;
            }
        }

        $q->[$idx] = \@keep;
    }
    
    $q->[NEXTCHECK] = $now + $q->[REPRIO];
    return;
}

=item shutdown

Same as Coro::Channel.

=cut

sub shutdown {
   Coro::Semaphore::adjust $_[0][SGET], 1_000_000_000;
}

=item size

Same as Coro::Channel.

An optional parameter allows you to specify the minimum priority level
that you want to check the size against, i.e., to ignore messages of
lower priority.  This can be used for example if you're in the middle of
an action and you want to check if there is a higher-priority message to
deal with before resuming the current activity.  This will not block.

=cut

sub size {
    my $min = @_ > 1 ? $_[1] - PRIO_MIN + DATA : DATA;
    sum map { $_ ? scalar @$_ : 0 } @{$_[0]}[$min..MAX];
}

=back

=cut

1;
