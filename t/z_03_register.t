#!perl
use strict;
no warnings;

use Test::More tests => 2;
use AnyEvent;
use AnyEvent::XMPP::Test;
use AnyEvent::XMPP::Stream::Client;
use AnyEvent::XMPP::Ext::Registration;
use AnyEvent::XMPP::Util qw/split_jid/;
use AnyEvent::XMPP::Stanza;

AnyEvent::XMPP::Test::check ('client');

my $cv = AnyEvent->condvar;

my $stream = AnyEvent::XMPP::Stream::Client->new (
   jid      => $JID1,
   password => $PASS,
   host     => $HOST,
   port     => $PORT,
);

$AnyEvent::XMPP::Stream::DEBUG = 2;

my $reg = AnyEvent::XMPP::Ext::Registration->new (delivery => $stream);

my $registered = 0;
my $logged_in  = 0;
my $unregistered = 1;


$stream->reg_cb (
   connected => sub {
      my ($stream, $h, $p) = @_;

      print "ok 1 - connected\n";
   },
   pre_authentication => sub {
      my ($stream) = @_;

      my $ev = $stream->current;
      $ev->stop;

      my ($username, $domain, $pass) = $stream->credentials;

      $reg->quick_registration ($username, $pass, sub {
         my ($error) = @_;

         if ($error) {
            print "# Couldn't register: " . $error->string . "\n";

         } else {
            $registered++;
         }

         my ($username2) = split_jid ($JID2);
         $reg->quick_registration ($username2, $pass, sub {
            my ($error) = @_;

            if ($error) {
               print "# Couldn't register second: " . $error->string . "\n";

            } else {
               $registered++;
            }

            $ev->continue;
         });
      });
   },
   stream_ready => sub {
      my ($stream) = @_;
      $logged_in = 1;

      $cv->send;
   },
   disconnected => sub {
      my ($stream, $h, $p) = @_;

      $stream->connect;
   }
);

$stream->connect;

$cv->recv;

is ($registered, 2, "registered successfully");
ok ($logged_in,  "logged in successfully");