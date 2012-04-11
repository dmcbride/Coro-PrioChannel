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

=over 4

=cut

use Coro qw(:prio);
use Coro::Semaphore ();

use List::Util qw(first sum);

sub SGET() { 0 }
sub SPUT() { 1 }
sub DATA() { 2 }

=item new

Create a new channel with the given maximum size.  Giving a size of one
defeats the purpose of a priority queue.

=cut

sub new {
    # we cheat, just like Coro::Channel.
   bless [
      (Coro::Semaphore::_alloc 0), # counts data
      (Coro::Semaphore::_alloc +($_[1] || 2_000_000_000) - 1), # counts remaining space
      [], # initially empty
   ]
}

=item put

Put the given scalar into the queue.  Optionally provide a priority between
L<Coro>::PRIO_MIN and L<Coro>::PRIO_MAX.

=cut

sub put {
   push @{$_[0][DATA + ($_[2]||PRIO_NORMAL()) - PRIO_MIN()]}, $_[1];
   Coro::Semaphore::up   $_[0][SGET];
   Coro::Semaphore::down $_[0][SPUT];
}

=item get

Return the next element from the queue at the highest priority, waiting if
necessary.

=cut

sub get {
   Coro::Semaphore::down $_[0][SGET];
   Coro::Semaphore::up   $_[0][SPUT];

   my $a = first { $_ && scalar @$_ } reverse @{$_[0]}[DATA()..DATA() + PRIO_MAX()-PRIO_MIN() + 1];

   ref $a ? shift @$a : undef;
}

=item shutdown

Same as Coro::Channel.

=cut

sub shutdown {
   Coro::Semaphore::adjust $_[0][SGET], 1_000_000_000;
}

=item size

Same as Coro::Channel.

=cut

sub size {
    sum map { $_ ? scalar @$_ : 0 } @{$_[0]}[DATA..DATA + PRIO_MAX()-PRIO_MIN() + 1];
}

=back

=cut

1;
