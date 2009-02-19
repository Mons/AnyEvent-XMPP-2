package AnyEvent::XMPP::Stanza;
use strict;
no warnings;
use AnyEvent::XMPP::Util qw/simxml/;
require Exporter;

our @ISA = qw/Exporter/;
our @EXPORT = qw/new_iq new_msg new_pres/;

=head1 NAME

AnyEvent::XMPP::Stanza - XMPP Stanza base class

=head1 SYNOPSIS

=head2 DESCRIPTION

This class represents a generic XMPP stanza. There are 3 subclasses,
which are used to represent the 3 main stanza types of XMPP:

  AnyEvent::XMPP::Message
  AnyEvent::XMPP::IQ
  AnyEvent::XMPP::Presence

=head2 FUNCTIONS

=item B<new_iq ($type, %args)>

This function generates a new L<AnyEvent::XMPP::IQ> object for you.

C<$type> may be one of these 4 values:

   set
   get
   result
   error

The destination and source of the stanza should be given by the C<to> and
C<from> attributes in C<%args>. C<%args> may also contain additional XML attributes
or these keys:

=over 4

=item create => C<$creation>

This is the most important parameter for any XMPP stanza, it
allows you to create the content of the stanza.

TODO: Document it!

=item cb => $callback

If you expect a reply to this IQ stanza you have to set a C<$callback>.
That callback will be called when either a response stanza was received
or the timeout triggered.

If the result was successful then the first argument of the callback
will be the result stanza.

If the result was an error or a timeout the first argument will be undef
and the second will contain an L<AnyEvent::XMPP::Error::IQ> object,
describing the error.

=item timeout => $seconds

This sets the timeout for this IQ stanza. It's entirely optional and
will be set to a default IQ timeout (see also L<AnyEvent::XMPP::Connection>
and L<AnyEvent::XMPP::IQTracker> for more details).

If you set the timeout to 0 no timeout will be generated.

=back

=cut

sub new_iq {
   my ($type, $from, $to, %args) = @_;
   AnyEvent::XMPP::IQ->new ($type, $from, $to, %args)
}

sub new_msg { }
sub new_pres { }

=item B<analyze ($node, $stream_ns)>

This class function analyzes the L<AnyEvent::XMPP::Node>
and tries to figure out what stanza type C<$node> is of
and returns a wrapper object around it with the corresponding
type.

C<$stream_ns> is the 'XML' namespace of the stream.

=cut

sub analyze {
   my ($node, $stream_ns) = @_;

   my $type;
   my $obj;

   if (not defined $node) {
      $type = 'end'

   } elsif ($node->eq ($stream_ns => 'presence')) {
      return AnyEvent::XMPP::Presence->new ($node, type => 'presence', stream_ns => $stream_ns);

   } elsif ($node->eq ($stream_ns => 'iq')) {
      return AnyEvent::XMPP::IQ->new ($node, type => 'iq', stream_ns => $stream_ns);

   } elsif ($node->eq ($stream_ns => 'message')) {
      return AnyEvent::XMPP::Message->new ($node, type => 'message', stream_ns => $stream_ns);

   } elsif ($node->eq (stream => 'features')) {
      return AnyEvent::XMPP::FeatureStanza->new ($node, type => 'features', stream_ns => $stream_ns);

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

   }

   AnyEvent::XMPP::Stanza->new ($node, type => $type, stream_ns => $stream_ns);
}

=head2 METHODS

=over 4

=item B<new (%args)>

=cut

sub new {
   my $this  = shift;
   my $class = ref($this) || $this;
   my $self  = { };
   $self = bless $self, $class;

   if (ref ($_[0])) {
      my $node = shift;
      (%$self) = (node => $node, @_);
      $self->internal_analyze;
   } else {
      $self->construct (@_);
   }

   return $self
}

sub want_id { $_[0]->{reply_cb} && not defined $_[0]->{attrs}->{id} }
sub set_id { $_[0]->{attrs}->{id} = $_[1] }
sub id { $_[0]->{attrs}->{id} }

sub type { $_[0]->{type} }
sub node { $_[0]->{node} }

sub reply_cb     { $_[0]->{reply_cb} }
sub set_reply_cb { $_[0]->{reply_cb} = $_[1] }
sub timeout      { $_[0]->{timeout} }
sub set_timeout  { $_[0]->{timeout} = $_[1] }

sub construct {
   my ($self) = @_;
}

sub internal_analyze {
   my ($self) = @_;
   my $node = $self->{node};
   $self->{type}  ||= $node->name;
   $self->{attrs}   = $node->attrs;
}

sub set_default_to {
   my ($self, $to) = @_;

   unless (defined $self->{attrs}->{to}) {
      $self->{attrs}->{to} = $to;
   }
}

sub set_default_from {
   my ($self, $from) = @_;

   unless (defined $self->{attrs}->{from}) {
      $self->{attrs}->{from} = $from;
   }
}

sub add {
   my ($self, $cb) = @_;
   push @{$self->{cbs}}, $cb;
}

sub _writer_serialize {
   my ($w, $arg) = @_;

   if (ref ($arg) eq 'HASH') {
      simxml ($w, %$arg);

   } elsif (ref ($arg) eq 'ARRAY') {
      _writer_serialize ($w, $_) for @$arg;

   } else {
      $arg->($w)
   }
}

sub serialize {
   my ($self, $writer) = @_;

   my @add;

   if (defined $self->{id}) {
      push @add, (id => $self->{id})
   }

   $self->{attrs} ||= {};

   $writer->stanza (
      $self->{type},
      {
         (map { $_ => $self->{attrs}->{$_} }
            grep { defined $self->{attrs}->{$_} }
               keys %{$self->{attrs}}),
         @add
      },
      $self->{cbs}
         ? (sub { _writer_serialize ($_[0], $self->{cbs}) }) : ()
   )
}

=item B<type>

This method returns the type of the stanza, which is
one of these:

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

=cut

=head1 AUTHOR

Robin Redeker, C<< <elmex@ta-sa.org> >>

=head1 SEE ALSO

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

package AnyEvent::XMPP::Message;
use strict;
no warnings;

use base qw/AnyEvent::XMPP::Stanza/;

package AnyEvent::XMPP::IQ;
use strict;
no warnings;

use base qw/AnyEvent::XMPP::Stanza/;

sub construct {
   my ($self, $type, %args) = @_;

   if (my $int = delete $args{create}) {
      $self->add ($int);
   }

   if (my $cb = delete $args{cb}) {
      $self->set_reply_cb ($cb);
   }

   if (my $to = delete $args{timeout}) {
      $self->set_timeout ($to);
   }

   $self->{want_id} = 1;

   $self->{type}          = 'iq';
   $self->{attrs}         = \%args;
   $self->{attrs}->{type} = $type;
}

sub is_reply {
   my ($self) = @_;

   $self->{attrs}->{type} eq 'result'
   || $self->{attrs}->{type} eq 'error'
}

sub iq_type {
   my ($self) = @_;

   $self->{attrs}->{type}
}

package AnyEvent::XMPP::Presence;
use strict;
no warnings;

use base qw/AnyEvent::XMPP::Stanza/;

package AnyEvent::XMPP::FeatureStanza;
use strict;
no warnings;

use base qw/AnyEvent::XMPP::Stanza/;

sub internal_analyze {
   my ($self) = @_;

   $self->SUPER::internal_analyze;

   my $node = $self->{node};

   my @bind  = $node->find_all ([qw/bind bind/]);
   my @tls   = $node->find_all ([qw/tls starttls/]);
   my @mechs = $node->find_all ([qw/sasl mechanisms/], [qw/sasl mechanism/]);


   $self->{sasl_mechs} = [ map { $_->text } @mechs ]
      if @mechs;
   $self->{tls}  = 1 if @tls;
   $self->{bind} = 1 if @bind;

   # and yet another weird thingie: in XEP-0077 it's said that
   # the register feature MAY be advertised by the server. That means:
   # it MAY not be advertised even if it is available... so we don't
   # care about it...
   # my @reg   = $node->find_all ([qw/register register/]);
}

sub tls        { (shift)->{tls} }
sub bind       { (shift)->{bind} }
sub sasl_mechs { (shift)->{sasl_mechs} }

1;