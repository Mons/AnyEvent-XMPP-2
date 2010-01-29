#!/usr/bin/env perl

use strict;
use lib::abs '../lib';
use Test::More tests => 5;
use AnyEvent::XMPP::Ext::Server::Util qw/arrxml/;

is_deeply
   arrxml [ key => 'value' ],
   {
      name => 'key',
      childs => [ 'value' ]
   },
   'simple';

is_deeply
   arrxml [ key => [ inkey => 'value' ] ],
   {
      name => 'key',
      childs => [
         {
            name => 'inkey',
            childs => [ 'value' ],
         }
      ]
   },
   'inner';

is_deeply
   arrxml [ key => { your => 'hash' } ],
   {
      name => 'key',
      childs => [
         { your => 'hash' }
      ]
   },
   'custom';

is_deeply
   arrxml [ key => '' ],
   {
      name => 'key',
      childs => [ '' ]
   },
   'empty';

is_deeply
   arrxml [ key => [] ],
   {
      name => 'key',
      childs => [  ]
   },
   'empty 2';

is_deeply
   arrxml [ key => [] ],
   {
      name => 'key',
      childs => [  ]
   },
   'empty 2';
