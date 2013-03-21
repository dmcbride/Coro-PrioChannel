use strict;
use warnings;
use Test::More qw/no_plan/;

use Time::HiRes qw/sleep/;
use Coro::PrioChannel;
use Coro qw/:prio/;

my $q = Coro::PrioChannel->new(undef, 0.1);
$q->put($_, PRIO_LOW) foreach 1 .. 10;

sleep 0.2;
$q->put(11, PRIO_NORMAL);

foreach my $n (1 .. 11) {
    my $item = $q->get;
    ok($n == $item, "$n == $item");
}