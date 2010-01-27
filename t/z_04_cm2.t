#!perl
use utf8;
use strict;
no warnings;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::XMPP::Test;
use AnyEvent::XMPP::CM;
use AnyEvent::XMPP::Util qw/cmp_bare_jid/;
use JSON -convert_blessed_universally;

my ($LH, $LP);
my $hdl;

my $cv = AE::cv;

tcp_server undef, undef, sub {
   my ($fh, $h, $p) = @_;

   $hdl = AnyEvent::Handle->new (
      fh => $fh,
      on_read => sub { }
   );

}, sub {
   my ($fh, $h, $p) = @_;
   ($LH, $LP) = ($h, $p);
   $cv->send;
   10
};

$cv->wait;

AnyEvent::XMPP::Test::check ('client');

print "1..2\n";

my $im = AnyEvent::XMPP::CM->new (connect_timeout => 2);

$im->set_accounts ($JID2 => [$PASS, { host => $LH, port => $LP }]);

my $c = cvreg $im, 'disconnected';
my ($jid, $h, $p, $msg, $recon) = $c->recv;

tp 1, $msg =~ /timeout/, 'defining connection timeout works';
tp 2, $recon > 0, 'got reconnect timeout';
