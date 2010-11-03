package AnyEvent::XMPP;
no warnings;
use strict;

=head1 NAME

AnyEvent::XMPP - An implementation of the XMPP Protocol

=head1 VERSION

Version 1.9903

=cut

our $VERSION = '1.9903';

=head1 SYNOPSIS

   use AnyEvent::XMPP::IM;

or:

   use AnyEvent::XMPP::Stream::Client;

or:

   use AnyEvent::XMPP::Stream::Component;

=head1 DESCRIPTION

This is the head module of the L<AnyEvent::XMPP> XMPP client protocol (as described in
RFC 3920 and RFC 3921) framework.

The earlier versions (0.51 and earlier) have a completely different API.
The scalability of the previous API in aspect of new and more XMPP extensions
exceeded a maintainable state. The new version also comes with less C dependencies,
there is no direct C dependency. Only L<Net::SSLeay>, which is used by L<AnyEvent::Handle>,
requires a C binding to the OpenSSL library.

Let me list some of the main modules/packages you will find in the L<AnyEvent::XMPP>
distribution:

L<AnyEvent::XMPP::IM> is a highlevel API for a multi-account XMPP client. It manages
connections for you and will load required extensions for everyday person to person
chats. It inherits it's connection management interface from L<AnyEvent::XMPP::CM>.

L<AnyEvent::XMPP::Stream::Client> this is a bare XMPP client connection which
includes client authentication. It will not do much more than connecting and authenticating
as client entity to an XMPP server. If you need presence handling and other stuff you
should take a look at the extension modules, of which you will find a summary
in L<AnyEvent::XMPP::Ext>.

You can also write XMPP components with the L<AnyEvent::XMPP::Stream::Component> API.

Most classes in L<AnyEvent::XMPP> which handle connections also implement the
L<AnyEvent::XMPP::Delivery> interface, which is an generic API for sending and
receiving XMPP stanzas. You also want to consult the documentation of
L<AnyEvent::XMPP::Node> which is used to represent XMPP stanzas. In context of
L<AnyEvent::XMPP::Node>s you should also read L<AnyEvent::XMPP::Meta>, which is
a documentation of meta attributes of L<AnyEvent::XMPP::Node> instances (which
can be accessed through the C<meta> method).

Some classes also inherit the L<AnyEvent::XMPP::StanzaHandler> interface, which
extends the L<AnyEvent::XMPP::Delivery> API with some specialized XMPP stanza
handling (mostly correct handling of IQ stanzas).

=head1 REQUIREMENTS

One of the major drawbacks I see for AnyEvent::XMPP is the long list of required
modules to make it work.

=over 4

=item L<AnyEvent>

For the I/O events, timers, TCP, TLS, DNS and I/O buffering.

=item L<Object::Event>

The former L<AnyEvent::XMPP::Event> module has been outsourced to the L<Object::Event>
module to provide a more generic way for more other modules to register and call
event callbacks.

=item L<MIME::Base64>

For SASL authentication

=item L<Authen::SASL>

For SASL authentication

=item L<Unicode::Stringprep>

For stringprep profile handling for JIDs.

=item L<Digest::SHA1>

For component authentication and old-style authentication.

=back

And yes, all these are essential for XMPP communication. Even though 'instant
messaging' and 'presence' is a quite simple problem XMPP somehow was successful
at making the task complicated enough to keep me busy for a long time.  But all
of that time wasn't only for the technology required to get it started, mostly
it was for all the quirks, hacks and badly applied "XML" in the protocol which
complicated the matter.

=head1 RELEASE NOTES

Here are some notes to the last releases (release of this version is at top):

=head2 Version

=over 4

=item * 0.51 and older

Older releases are not compatible with the 1.0 API.

If you need to install older releases try this:

    cpan> install E/EL/ELMEX/AnyEvent-XMPP-0.51.tar.gz

Or if tests fail:

   cpan> force install E/EL/ELMEX/AnyEvent-XMPP-0.51.tar.gz

However,  I don't give any support for 0.x versions of this module anymore. I
might answer questions, but if you hit bugs in the 0.x versions you are on your
own.

=back

=head2 TODO

There are still lots of items on the TODO list (see also the TODO file
in the distribution of AnyEvent::XMPP).

=head1 TEST SUITE

If you are a developer and want to test either a server or maybe just whether
this module passes some basic tests you might want to run the developer test
suite.

This test suite is not enabled by default because it requires some human
interaction to set it up, please see L<AnyEvent::XMPP::TestClient> for hints about
the setup procedure for the test suite.

I wrote the test suite mostly because I wanted to make sure I didn't break
something essential before a release. The tests don't cover everything and I
don't plan to write a test for every single function in the API, that would
slow down development considerably for me. But I hope that some grave show
stopper bugs in releases are prevented with this test suite.

The tests are also useful if you want to test a server implementation. But
there are maybe of course conformance issues with L<AnyEvent::XMPP> itself, so if
you find something where L<AnyEvent::XMPP> doesn't conform to the XMPP RFCs or XEPs
consult the L<BUGS> section below.

If you find a server that doesn't handle something correctly but you need to
interact with it you are free to implement workarounds and send me a patch, or
even ask me whether I might want to look into the issue (I can't guarantee
anything here, but I want this module to be as interoperable as possible. But
if the implementation of a workaround for some non-conformant software will
complicate the code too much I'm probably not going to implement it.).

Of course, if you find a bug in some server implementation don't forget to file
a bugreport to them, one hack less in L<AnyEvent::XMPP> means more time for bug
fixing and improvements and new features.

=head1 Why (yet) another XMPP module?

The main outstanding feature of this module in comparison to the other XMPP
(aka Jabber) modules out there is the support for L<AnyEvent>. L<AnyEvent>
permits you to use this module together with other I/O event based programs and
libraries (ie. L<Gtk2> or L<Event>).

The other modules could often only be integrated in those applications or
libraries by using threads. I decided to write this module because I think CPAN
lacks an event based XMPP module. Threads are unfortunately not an alternative
in Perl at the moment due the limited threading functionality they provide and
the global speed hit. I also think that a simple event based I/O framework
might be a bit easier to handle than threads.

Another thing was that I didn't like the APIs of the other modules. In
L<AnyEvent::XMPP> I try to provide low level modules for speaking XMPP as defined
in RFC 3920 and RFC 3921 (see also L<AnyEvent::XMPP::Connection> and
L<AnyEvent::XMPP::IM::Connection>). But I also try to provide a high level API for
easier usage for instant messaging tasks and clients (eg. L<AnyEvent::XMPP::Client>).

=head1 Supported extensions

See L<AnyEvent::XMPP::Ext> for a list.

=head1 EXAMPLES

Following examples are included in this distribution:

=over 4

=item B<samples/simple_example_1>

This example script just connects to a server and sends a message and
also displays incoming messages on stdout.

=item B<samples/conference_lister>

See below.

=item B<samples/room_lister>

See below.

=item B<samples/room_lister_stat>

These three scripts implements a global room scan.  C<conference_lister> takes
a list of servers (the file is called C<servers.xml> which has the same format as
the xml file at L<http://www.jabber.org/servers.xml>). It then scans all
servers for chat room services and lists them into a file C<conferences.stor>,
which is a L<Storable> dump.

C<room_lister> then reads that file and queries all services for rooms, and then
all rooms for their occupants. The output file is C<room_data.stor>, also a L<Storable>
dump, which in turn can be read with C<room_lister_stat>, which transform
the data structures into something human readable.

These scripts are a bit hacky and quite complicated, but maybe it's of any
value for someone. You might note L<samples/EVQ.pm> which is a module that
handles request-throttling (You don't want to flood the server and risk
getting the admins attention :).

=item B<samples/simple_component>

This is a (basic) skeleton for a jabber component.

=item B<samples/simple_oob_retriever>

This is a simple out of band file transfer receiver bot.  It uses C<curl> to
fetch the files and also has the sample functionality of sending a file url for
someone who sends the bot a 'send <filename>' message.

=item B<samples/simple_register_example>

This is a example script which allows you to register, unregister and change
your password for accounts. Execute it without arguments for more details.

=item B<samples/disco_info>

This is a small example tool that allows you to fetch the software version,
disco info and disco items information about a JID.

=item B<samples/talkbot>

This is a simple bot that will read lines from a file and recite them
when you send it a message. It will also automatically allow you to subscribe
to it. Start it without commandline arguments to be informed about the usage.

=item B<samples/retrieve_roster>

This is a simple example script that will retrieve the roster
for an account and print it to stdout. You start it like this:

   samples/# ./retrieve_roster <jid> <password>

=item B<samples/display_avatar>

This is just a small example which should display the avatar
of the account you connect to. It can be used like this:

   samples/# ./display_avatar <jid> <password>

=back

For others, which the author might forgot or didn't want to
list here see the C<samples/> directory.

More examples will be included in later releases, please feel free to ask the
L</AUTHOR> if you have any questions about the API. There is also an IRC
channel, see L</SUPPORT>.

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 BUGS

Please note that I'm currently (April 2010) the only developer on this project
and I'm very busy with my studies in Computer Science. If you want to ease my
workload or want timely releases, please send me patches instead of bug reports
or feature requests. I won't forget the reports or requests if you can't or
didn't send patches, but I can't guarantee immediate response. But I will of
course try to fix/implement them as soon as possible!

Also try to be as precise as possible with bug reports, if you can't send a
patch, it would be best if you find out which code doesn't work and tell me
why.

Please report any bugs or feature requests to
C<bug-anyevent-xmpp at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-XMPP>.
I will be notified and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::XMPP

You can also look for information at:

=over 4

=item * IRC: AnyEvent::XMPP IRC Channel

  IRC Network: http://freenode.net/
  Server     : chat.freenode.net
  Channel    : #ae_xmpp

  Feel free to join and ask questions!

=item * AnyEvent::XMPP Project Site

L<http://www.ta-sa.org/net_xmpp2>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AnyEvent-XMPP>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AnyEvent-XMPP>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-XMPP>

=item * Search CPAN

L<http://search.cpan.org/dist/AnyEvent-XMPP>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to the XSF for the development of an open instant messaging protocol (even though it uses "XML").

And thanks to all people who had to listen to my desperate curses about the
brokenness/braindeadness of XMPP. Without you I would've never brought this
module to a usable state.

Thanks to:

=over 4

=item * J. Cameijo Cerdeira

For pointing out a serious bug in C<split_jid> in L<AnyEvent::XMPP::Util>
and suggesting to add a timeout argument to the C<connect> method of
L<AnyEvent::XMPP::SimpleConnection>.

=item * Carlo von Loesch (aka lynX) L<http://www.psyced.org/>

For pointing out some typos.

=item * All other people ..

... I mentioned in the CONTRIBUTORS file which comes with the L<AnyEvent::XMPP>
distribution.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2007-2010 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of AnyEvent::XMPP
