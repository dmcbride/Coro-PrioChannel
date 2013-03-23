use strict;
use warnings;
use Test::More tests => 11;

use Coro::PrioChannel;
use Coro     qw/:prio/;

# if we load EV, it complains with a warning, force this to use
# the pure-perl loop and we're okay.
use AnyEvent::Loop;
use AnyEvent; AnyEvent::detect;

my $q = Coro::PrioChannel->new(undef, 0.1);
$q->put($_, PRIO_LOW) foreach 1 .. 10;

Coro::AnyEvent::sleep(0.2);
$q->put(11, PRIO_NORMAL);

foreach my $n (1 .. 11) {
    my $item = $q->get;
    is($item, $n, '$n == $item');
}
