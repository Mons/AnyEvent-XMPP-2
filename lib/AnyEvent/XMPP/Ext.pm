package AnyEvent::XMPP::Ext;
no warnings;
use strict;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;

use base qw/Object::Event/;

=head1 NAME

AnyEvent::XMPP::Ext - Extension baseclass and documentation

=head1 DESCRIPTION

This module also has documentation about the supported extensions and also is a
base class for all extensions that can be added via the C<add_extension> method
of the classes that derive from L<AnyEvent::XMPP::Extendable>. (That are for
example: L<AnyEvent::XMPP::Stream> (and derived classes), L<AnyEvent::XMPP::CM>
and others).

This class inherits a callback API from the L<Object::Event> class. Please consult
the documentation of L<Object::Event> for further information about that API.

=head1 METHODS

=over 4

=item my $ext = AnyEvent::XMPP::Ext::*->new

This is the constructor that should be inherited and not overwritten by
L<AnyEvent::XMPP> extensions. It should also not be called directly, instead
the L<AnyEvent::XMPP::Extendable> class takes care of proper instance creation.

If you need to do initialization in your extension have a look at the C<init> method below.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = $class->SUPER::new (@_);

   if ($self->disco_feature) {
      my @own_disco_feat = $self->disco_feature;

      $self->{disco_feat_guard} = $self->{extendable}->reg_cb (
         discover_features => sub {
            my ($ext, $features) = @_;
            push @$features, @own_disco_feat;
            ()
         }
      );
   }

   $self->init;
   $self
}


=item $ext->init ()

This method can be overwritten by the subclasses and be used for initialization of the
extension.

=cut

sub init { } # just a default implementation...

=item my (@pkgs) = $ext->required_extensions ()

This method can be overwritten by the extension and should return
a list of package names of extensions that need to be loaded and configured
before this extension can be successfully initialzed.

=cut

sub required_extensions { }

=item my (@pkgs) = $ext->autoload_extensions ()

This method can be overwritten and should return a list of package names
of extensions that should be automatically loaded (and not require any special setup)
before the extension is loaded.

=cut

sub autoload_extensions { }

=item my (@uris) = $ext->disco_feature ()

This method can be overwritten by the extension and should return
a list of namespace URIs of the features that the extension enables.

=cut

sub disco_feature { }

=back

=head1 SUPPORTET XMPP EXTENSIONS

This is the list of supported XMPP extensions:

B<NOTE>: Not all modules in the L<AnyEvent::XMPP::Ext::> namespace actually
implement the L<AnyEvent::XMPP::Ext> interface and can't be used to extend
L<AnyEvent::XMPP::Extendable> objects directly.

TODO: Confirm this!

=over 4

=item XEP-0004 - Data Forms (Version 2.8)

This extension handles data forms as described in XEP-0004. It's not an extension
you can load via the L<AnyEvent::XMPP::Extendable> interface, but just a special
utility class: L<AnyEvent::XMPP::Util::DataForm> allows you to construct, receive and
answer data forms. This is necessary for all sorts of things in XMPP.
For example XEP-0055 (Jabber Search) or also In-band registration.

=item XEP-0030 - Service Discovery (Version 2.3)

This extension allows you to send service discovery requests and
define a set of discoverable information. See also L<AnyEvent::XMPP::Ext::Disco>.

=item XEP-0045 - Multi-User Chat (Version ?)

This extension implements basic functionality for multi-user chats.
See also L<AnyEvent::XMPP::Ext::MUC>.

=item XEP-0054 - vcard-temp (Version 1.1)

This extension allows the retrieval and storage of XMPP vcards
as defined in XEP-0054. It is implemented by L<AnyEvent::XMPP::Ext::VCard>.

=item XEP-0066 - Out of Band Data (Version 1.5)

This extension allows to receive and send out of band data URLs
and provides helper functions to handle jabber:x:oob data.
See also L<AnyEvent::XMPP::Ext::OOB>.

=item XEP-0068 - Field Standardization for Data Forms (Version 1.1)

Handling of the special hidden FORM_TYPE field in Data Forms,
see also L<AnyEvent::XMPP::Util::DataForm>.

=item XEP-0077 - In-Band Registration (Version 2.2)

This extension lets you register new accounts "in-band".
For details please take a look at L<AnyEvent::XMPP::Ext::Registration>.

=item XEP-0078 - Non-SASL Authentication (Version 2.3)

After lots of sweat and curses I implemented finally iq auth.
Unfortunately the XEP-0078 specifies things that are not implemented,
in fact the only server that worked was openfire and psyced.org.

So I de-analyzed the iq auth and now it just barfs the IQ set out
on the stream with the username and the password.

You can also completely disable iq auth, well, just see the documentation
of L<AnyEvent::XMPP::Stream::Client>

=item XEP-0082 - XMPP Date and Time Profiles (Version 1.0)

Implemented some functions to deal with XMPP timestamps, see L<AnyEvent::XMPP::Util>
C<to_xmpp_time>, C<to_xmpp_datetime>, C<from_xmpp_datetime>.

=item XEP-0086 - Error Condition Mappings (Version 1.0)

   "A mapping to enable legacy entities to correctly handle errors from XMPP-aware entities."

This extension will enable sending of the old error codes when generating a stanza
error with for example the C<write_error_tag> method of L<AnyEvent::XMPP::Writer>.

Also if only the old numeric codes are supplied the L<AnyEvent::XMPP::Error::Stanza>
class tries to map the numeric codes to the new error conditions if possible.

=item XEP-0091 - Delayed Delivery (Version 1.3)

See also XEP-0203 below.

=item XEP-0092 - Software Version (Version 1.1)

The ability to answer to software version, name and operating system requests
and being able to send such requests is implemented in L<AnyEvent::XMPP::Ext::Version>.

=item XEP-0114 - Jabber Component Protocol (Version 1.5)

This extension allows you to connect to a server as a component
and makes it possible to implement services like pubsub, muc, or
whatever you can imagine (even gateways).
See documentation of L<AnyEvent::XMPP::Component> and the example
C<samples/simple_component>.

=item XEP-0153 - vCard-Based Avatars (Version 1.0)

Only partially support - mostly for decoding/encoding - is currently available,
see also L<AnyEvent::XMPP::Ext::VCard>.

=item XEP-0199 - XMPP Ping (Version 1.0)

You can send ping requests to other entities and also are
able to reply to them. On top of that the L<AnyEvent::XMPP::Ext::Ping>
extension implements a connection timeout mechanism based on this.

=item XEP-0203 - Delayed Delivery (Version 1.0)

Both delayed delivery XEPs are supported and are implemented by
L<AnyEvent::XMPP::Ext::Delay>.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007-2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of AnyEvent::XMPP
