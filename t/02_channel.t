# stolen from Coro::Channel's tests

$|=1;
print "1..19\n";

use Coro;
use Coro::PrioChannel;

my $q = new Coro::PrioChannel 1;

async { # producer
   for (1..9) {
      print "ok ", $_*2, "\n";
      $q->put($_);
   }
};

print "ok 1\n";
cede;

for (11..19) {
   my $x = $q->get;
   print $x == $_-10 ? "ok " : "not ok ", ($_-10)*2+1, "\n";
}

