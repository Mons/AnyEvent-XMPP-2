package AnyEvent::XMPP::Meta;
use strict;
no warnings;
use Scalar::Util qw/weaken/;
use AnyEvent::XMPP::Util qw/cmp_jid cmp_bare_jid stringprep_jid/;

=head1 NAME

AnyEvent::XMPP::Meta - Meta information for AnyEvent::XMPP::Node

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item AnyEvent::XMPP::Meta->new ($node)

Creates a new meta information of the L<AnyEvent::XMPP::Node> object
in C<$node>. The result will be a meta information object, which
will be a hash reference which you have to access directly to get the
meta information (like the type of the stanza, or whether the features
stanza came with the bind feature, ...).

Meta information is also crucial for internal routing in L<AnyEvent::XMPP>.
The C<src> and C<dest> meta keys are used for this. See below.

Defined keys are given in the B<META TYPE> and B<TYPES> section below.

=cut

sub new {
   my $this  = shift;
   my $class = ref($this) || $this;
   my $self  = { };
   bless $self, $class;

   $self->analyze (@_);

   return $self
}

sub analyze {
   my ($self, $node) = @_;

   my $type;

   if ($node->eq (stanza => 'presence')) {
      $type = 'presence';
      $self->analyze_presence ($node);

   } elsif ($node->eq (stanza => 'iq')) {
      $type = 'iq';
      $self->analyze_iq ($node);

   } elsif ($node->eq (stanza => 'message')) {
      $type = 'message';
      $self->analyze_message ($node);

   } elsif ($node->eq (stream => 'features')) {
      $type = 'features';
      $self->analyze_features ($node);

   } elsif ($node->eq (tls => 'proceed')) {
      $type = 'tls_proceed';

   } elsif ($node->eq (tls => 'failure')) {
      $type = 'tls_failure';

   } elsif ($node->eq (sasl => 'challenge')) {
      $type = 'sasl_challenge'

   } elsif ($node->eq (sasl => 'success')) {
      $type = 'sasl_success'

   } elsif ($node->eq (sasl => 'failure')) {
      $type = 'sasl_failure'

   } elsif ($node->eq (stream => 'error')) {
      $type = 'error'

   } else {
      $type = 'unknown';
   }

   $self->{type} = $type;
}

sub add_sent_cb {
   my ($self, $cb) = @_;
   push @{$self->{sent_cb}}, $cb;
}

sub sent_cbs {
   my ($self) = @_;
   @{$self->{sent_cb} || []}
}

sub set_reply_cb {
   my ($self, $cb, $tout) = @_;
   $self->{reply_cb}      = $cb;
   $self->{reply_timeout} = $tout;
}

=back

=head1 LANGAUGE

Each stanza sent over the stream has a default language attached to it.
It is usually defaulted by the stream it was received by or sent with.

The C<lang> meta attribute will contain the language of the stanza,
which will be defaulted to the receiving stream's language.

If the stanza is on it's way out the C<lang> meta attribute will
be used to determine whether to attach a xml:lang attribute on
the outgoing stanza. That is done if the C<lang> attribute is defined
and doesn't match the outgoing stream default language.

=head1 SOURCE & DESTINATION

The two meta keys C<src> and C<dest> are used for internal routing and for
assigning each stanza with a source.

In case we receive a stanza the C<dest> field is set to the resources JID the
stanza was received by. Such a resource can be a client resource or even the
JID of a component.

The key C<src> is used for stanzas that are ought to be routed outside
of the application. It is used for instance by L<AnyEvent::XMPP::IM> to
figure out which client resource/connection to use to send the stanza.

=head1 META TYPE

The meta information is basically a hash. The key that all meta informations
for XMPP stanzas have in common is the C<type> key, which defines which type
the stanza is of, possible values are:

   presence
   iq
   message

   features
   error

   tls_proceed
   tls_failure

   sasl_challenge
   sasl_success
   sasl_failure

   unknown

=head1 TYPES

Here are the possible per type keys defined:

=over 4

=item B<features>

This is the type of the features stanza which is received after an XMPP Stream
was connected. It has these further keys:

=over 4

=item tls => $bool

=item bind => $bool

=item session => $bool

These are flags which are true if the features stanza came with the
corresponding feature enabled.

=item sasl_mechs => $mech_arrayref

C<$mech_arrayref> is an array reference which contains the SASL mechanisms
which were advertised by the server.

=back

=cut

sub analyze_features {
   my ($self, $node) = @_;

   my @mechs = $node->find_all ([qw/sasl mechanisms/], [qw/sasl mechanism/]);

   $self->{sasl_mechs} = [ map { $_->text } @mechs ]
      if @mechs;

   $self->{tls}     = 1 if $node->find_all ([qw/tls starttls/]);
   $self->{bind}    = 1 if $node->find_all ([qw/bind bind/]);
   $self->{session} = 1 if $node->find_all ([qw/session session/]);

   # and yet another weird thingie: in XEP-0077 it's said that
   # the register feature MAY be advertised by the server. That means:
   # it MAY not be advertised even if it is available... so we don't
   # care about it...
   # my @reg = $node->find_all ([qw/register register/]);
}

=item B<presence>

This is the type of a presence stanza, that either contains
presence information or subscription-state changing requests.

The meta information for those stanzas contains these further keys:

=over 4

=item is_resource_presence => $bool

C<$bool> is true whenever the presence originated from the same bare JID it was
received at. This means that some resource changed it's presence status.

=item presence => 'available' | 'unavailable' | undef

If this is not undef this stanza contains real presence information
and not just a subscription related request.

=item error => $error

If this meta attribute is set this stanza is an error stanza and C<$error>
contains the L<AnyEvent::XMPP::Error::Presence> object which describes
the error.

=back

=cut

sub analyze_presence {
   my ($self, $node) = @_;

   my $from = stringprep_jid $node->attr ('from');
   my $to   = stringprep_jid $node->attr ('to');

   $self->{is_resource_presence} = cmp_bare_jid ($from, $to);

   if ((not defined $node->attr ('type')) || $node->attr ('type') eq 'unavailable') {
      $self->{presence} = $node->attr ('type') || 'available';

   } elsif ($node->attr ('type') eq 'error' && $node->find (stanza => 'error')) {
      weaken $node;
      $self->{error} = AnyEvent::XMPP::Error::Presence->new (node => $node);
   }
}

=item B<message>

=over 4

=item error => $error

If this meta attribute is set this stanza is an error stanza and C<$error>
contains the L<AnyEvent::XMPP::Error::Message> object which describes
the error.

=back

=cut

sub analyze_message {
   my ($self, $node) = @_;

   if ($node->attr ('type') eq 'error' && $node->find (stanza => 'error')) {
      weaken $node;
      $self->{error} = AnyEvent::XMPP::Error::Message->new (node => $node);
   }
}

=item B<iq>

=over 4

=item error => $error

If this meta attribute is set this stanza is an error stanza and C<$error>
contains the L<AnyEvent::XMPP::Error::IQ> object which describes
the error.

=back

=cut

sub analyze_iq {
   my ($self, $node) = @_;

   if ($node->attr ('type') eq 'error' && $node->find (stanza => 'error')) {
      weaken $node;
      $self->{error} = AnyEvent::XMPP::Error::IQ->new (node => $node);
   }
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex@ta-sa.org> >>

=head1 SEE ALSO

=head1 COPYRIGHT & LICENSE

Copyright 2009, 2010 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

