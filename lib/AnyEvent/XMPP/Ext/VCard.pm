package AnyEvent::XMPP::Ext::VCard;
use AnyEvent::XMPP::Ext;
no warnings;
use strict;

use MIME::Base64;
use Digest::SHA1 qw/sha1_hex/;
use Scalar::Util;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;
use AnyEvent::XMPP::Util qw/prep_bare_jid new_iq new_reply/;

use base qw/AnyEvent::XMPP::Ext/;

=head1 NAME

AnyEvent::XMPP::Ext::VCard - VCards (XEP-0054)

=head1 SYNOPSIS

   my $vcard = $con->add_ext ("VCard");

   $vcard->retrieve ($src, $jid, sub {
      my ($vcard, $src, $jid, $vcard, $error) = @_;

      if (defined $error) {
         print "error: " . $error->string . "\n";
      } else {
         # do something with $vcard
      }
   });

   $vcard->store ($src, $vcard, sub {
      my ($vcard, $src, $vcard, $error) = @_;
      # ...
   });

=head1 DESCRIPTION

This extension handles setting and retrieval of the VCard (XEP-0054).  It has
also support to parse and decode the VCard based avatars (XEP-0153).
But this module does not implement handling of the avatar picture hashes.

For example see the test suite of L<AnyEvent::XMPP>.

=head1 METHODS

=over 4

=cut

sub required_extensions { 'AnyEvent::XMPP::Ext::Presence' }

sub disco_feature { xmpp_ns ('vcard') }

sub init {
   my ($self) = @_;
}


=item B<store ($src, $vcard, $cb)>

This method will store your C<$vcard> on the connected server.
C<$cb> is called when either an error occured or the storage was successful.
If an error occured the first argument is not undefined and contains an
L<AnyEvent::XMPP::Error::IQ> object.

C<$src> should be the source JID of one of your connected resources.

C<$vcard> has a data structure as described below in B<VCARD STRUCTURE>.

=cut

sub store {
   my ($self, $src, $vcard, $cb) = @_;

   my $vchld = $self->encode_vcard ($vcard);

   $self->{extendable}->send (new_iq (
      set =>
         src => $src,
      create => {
         node => { dns => vcard => name => 'vCard', childs => $vchld }
      }, cb => sub {
         my ($n, $e) = @_;

         $cb->($e);
      }
   ));
}

=item B<retrieve ($src, $jid, $cb)>

This method will retrieve the vCard for C<$jid> via the source resource C<$src>.
If C<$jid> is undefined the vCard of yourself is retrieved.

The callback C<$cb> is called when an error occured or the vcard was retrieved.
The first argument to C<$cb> is the vCard itself (as described in B<VCARD STRUCTURE>
below) and the second argument is the error, if an error occured
(undef otherwise).

=cut

sub retrieve {
   my ($self, $src, $jid, $cb) = @_;

   $self->{extendable}->send (new_iq (
      get =>
         src => $src,
         (defined $jid ? (to  => $jid) : ()),
      create => { node => { dns => vcard => name => 'vCard' } },
      cb => sub {
         my ($n, $e) = @_;

         if ($e) {
            $cb->(undef, $e);
         } else {
            my ($vcard) = $n->find_all ([qw/vcard vCard/]);
            $vcard = $self->decode_vcard ($vcard);
            $cb->($vcard);
         }
      }
   ));
}

sub decode_vcard {
   my ($self, $vcard) = @_;
   my $ocard = {};

   for my $cn ($vcard->nodes) {
      if ($cn->nodes) {
         my $sub = {};
         for ($cn->nodes) {
            $sub->{$_->name} = $_->text
         }
         push @{$ocard->{$cn->name}}, $sub;
      } else {
         push @{$ocard->{$cn->name}}, $cn->text;
      }
   }

   if (my $p = $ocard->{PHOTO}) {
      my $first = $p->[0];

      if ($first->{BINVAL} ne '') {
         $ocard->{_avatar} = decode_base64 ($first->{BINVAL});
         $ocard->{_avatar_hash} = sha1_hex ($ocard->{_avatar});
         $ocard->{_avatar_type} = $first->{TYPE};
      }
   }

   $ocard
}

sub encode_vcard {
   my ($self, $vcardh) = @_;

   if ($vcardh->{_avatar}) {
      $vcardh->{PHOTO} = [
         {
            BINVAL => encode_base64 ($vcardh->{_avatar}),
            TYPE => $vcardh->{_avatar_type}
         }
      ];
   }

   my @childs;

   for my $ve (keys %$vcardh) {
      next if substr ($ve, 0, 1) eq '_';

      for my $el (
         @{ref ($vcardh->{$ve}) eq 'ARRAY'
              ? $vcardh->{$ve} : [$vcardh->{$ve}]}
      ) {
         if (ref $el) {
            push @childs,
               {
                  dns => 'vcard', name => $ve, childs => [
                     map {
                        (not (defined $el->{$_}) || $el->{$_} eq '')
                           ? { dns => 'vcard', name => $_ }
                           : { dns => 'vcard', name => $_,
                               childs => [ $el->{$_} ] }
                     } keys %$el
                  ]
               }

         } elsif ((not defined $el) || $el eq '') {
            push @childs, { dns => 'vcard', name => $ve }

         } else {
            push @childs, { dns => 'vcard', name => $ve, childs => [ $el ] }
         }
      }
   }

   \@childs
}

=back

=head1 VCARD STRUCTURE

As there are currently no nice DOM implementations in Perl and I strongly
dislike the DOM API in general this module has a simple Perl datastructure
without cycles to represent the vCard.

First an example: A fetched vCard hash may look like this:

  {
    'URL' => ['http://www.ta-sa.org/'],
    'ORG' => [{
               'ORGNAME' => 'nethype GmbH'
             }],
    'N' => [{
             'FAMILY' => 'Redeker'
           }],
    'EMAIL' => ['elmex@ta-sa.org'],
    'BDAY' => ['1984-06-01'],
    'FN' => ['Robin'],
    'ADR' => [
       {
         HOME => undef,
         'COUNTRY' => 'Germany'
       },
       {
          WORK => undef,
          COUNTRY => 'Germany',
          LOCALITY => 'Karlsruhe'
       }
    ],
    'NICKNAME' => ['elmex'],
    'ROLE' => ['Programmer']
  }

The keys represent the toplevel element of a vCard, the values are always array
references containig one or more values for the key. If the value is a
hash reference again it's value will not be an array reference but either undef
or plain values.

The values of the toplevel keys are all array references because fields
like C<ADR> may occur multiple times.

Consult XEP-0054 for an explanation what these fields mean or contain.

There are special fields in this structure for handling avatars:
C<_avatar> contains the binary data for the avatar image.
C<_avatar_hash> contains the sha1 hexencoded hash of the binary image data.
C<_avatar_type> contains the mime type of the avatar.

If you want to store the vcard you only have to set C<_avatar> and C<_avatar_type>
if you want to store an avatar.

=head1 EVENTS

The vcard extension will emit these events:

=over 4

=item retrieve_vcard_error => $iq_error

When a vCard retrieval was not successful, this event is emitted.
This is necessary as some retrievals may happen automatically.

=item vcard => $jid, $vcard

Whenever a vCard is retrieved, either automatically or manually,
this event is emitted with the retrieved vCard.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007-2010 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
