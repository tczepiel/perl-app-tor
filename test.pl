use strict;
use warnings;

use App::Tor;

my $tor = App::Tor->new(
    tor_client_binary => '/usr/bin/tor',
);

my $ua = $tor->get_ua();
my $ret =$ua->get("http://google.com");

if ( $ret->is_success ) {
    print "it works\n";
}
