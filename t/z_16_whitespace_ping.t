#!perl
use strict;
no warnings;
use utf8;

use AnyEvent;
use AnyEvent::XMPP::Test;
use AnyEvent::XMPP::Stream::Client;
use AnyEvent::XMPP::Ext::Registration;
use AnyEvent::XMPP::Util qw/split_jid new_message xmpp_datetime_as_timestamp/;

AnyEvent::XMPP::Test::check ('client');

my $cv = AnyEvent->condvar;

my $stream = AnyEvent::XMPP::Stream::Client->new (
   jid      => $JID1,
   password => $PASS,
   whitespace_ping_interval => 1,
);

my $to;
my $ws;
$stream->reg_cb (
   error => sub {
      my ($stream, $error) = @_;
      print "# error: " . $error->string . "\n";
      $stream->stop_event;
   },
   debug_send => sub {
      my ($stream, $data) = @_;

      if ($data eq ' ') {
         $ws = 1;
         $stream->send_end;
         $cv->send;
      }
   },
   stream_ready => sub {
      my ($stream) = @_;
      print "ok 1 - logged in\n";
      $to = AE::timer 3, 0, sub { $stream->send_end };
   },
   disconnected => sub {
      my ($stream, $h, $p) = @_;
      $cv->send;
   }
);

$stream->connect;

$cv->recv;

tp (2, $ws, "sent whitespace ping");

print "1..2\n";
