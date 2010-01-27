#!perl
use strict;
use Test::More tests => 4;
use AnyEvent::XMPP::Node qw/simxml/;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;

my %def = (
   xmpp_ns ('stream') => 'stream',
   xmpp_ns ('client') => ''
);

my $stream_el =
   AnyEvent::XMPP::Node->new ('http://etherx.jabber.org/streams' => 'stream');

$stream_el->attr (test => 10);

$stream_el->attr_ns ('x:foobar', gnarf => 20);

my ($k_before) = grep { /\|test$/ } keys %{$stream_el->attrs};

$stream_el->namespace ('jabber:client');

my ($k_after) = grep { /\|test$/ } keys %{$stream_el->attrs};

my (@a)  = keys %{$stream_el->elem_attrs};
my (@a2) = keys %{$stream_el->attrs};

is (scalar (@a),  1, 'elem_attrs returned only one attribute');
is (scalar (@a2), 2, 'attrs returned two attributes');


is ($k_before, 'http://etherx.jabber.org/streams|test', 'before key got correct namesapace');
is ($k_after,  'jabber:client|test', 'after key got correct namesapace');
