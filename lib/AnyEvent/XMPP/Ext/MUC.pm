package AnyEvent::XMPP::Ext::MUC;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;
use AnyEvent::XMPP::Util qw/stringprep_jid new_iq new_reply join_jid split_jid res_jid
                            extract_lang_element prep_bare_jid new_presence cmp_jid/;
use Scalar::Util qw/weaken/;
use AnyEvent::XMPP::Error::Presence;
use AnyEvent::XMPP::Util::DataForm;
use strict;
no warnings;

use base qw/AnyEvent::XMPP::Ext/;

=head1 NAME

AnyEvent::XMPP::Ext::MUC - XEP-0045: Multi-User Chat

=head1 SYNOPSIS

   my $muc = $con->add_ext ('MUC');

   $muc->reg_cb (
      entered  => sub {
         my ($muc, $resjid, $roomjid, $node) = @_;
         # ...
      },
      message => sub {
         my ($muc, $resjid, $roomjid, $node) = @_;
         # ...
      }
   );

   $muc->join ($mucjid);

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut

sub required_extensions { 'AnyEvent::XMPP::Ext::Presence' }

sub disco_feature { }

sub init {
   my ($self) = @_;

   $self->{pres} = $self->{extendable}->get_ext ('Presence');

   $self->{nickcollision_cb} ||= sub {
      my $nick = shift;
      $nick . '_'
   };

   my $old_presence_holder;

   $self->{iq_guard} =
      $self->{extendable}->reg_cb (
         recv_presence => 550 => sub {
            my ($ext, $node) = @_;

            my $resjid = $node->meta->{dest};
            my $from   = prep_bare_jid ($node->attr ('from'));

            if (exists $self->{rooms}->{$resjid}
                && exists $self->{rooms}->{$resjid}->{$from}) {

               if (not ($node->meta->{error})
                   && $node->meta->{presence}) {

                  # we need this to differenciate a join from a presence change
                  ($old_presence_holder) =
                     $self->{pres}->presences ($resjid, $node->attr ('from'));
               }
            }
         },
         recv_presence => 450 => sub {
            my ($ext, $node) = @_;

            my $resjid = $node->meta->{dest};
            my $from   = prep_bare_jid ($node->attr ('from'));

            if (exists $self->{rooms}->{$resjid}
                && exists $self->{rooms}->{$resjid}->{$from}) {

               $self->handle_presence ($resjid, $from, $node, $old_presence_holder);
               undef $old_presence_holder;

               $ext->stop_event;
            }
         },
         recv_message => 450 => sub {
            my ($ext, $node) = @_;

            my $resjid = $node->meta->{dest};
            my $from   = prep_bare_jid ($node->attr ('from'));

            if (exists $self->{rooms}->{$resjid}
                && exists $self->{rooms}->{$resjid}->{$from}) {

               $self->handle_message ($resjid, $from, $node);
            }
         },
         source_unavailable => 450 => sub {
            my ($ext, $resjid) = @_;

            for (keys %{$self->{rooms}->{$resjid} || {}}) {
               $self->event (left => $resjid, $_);
            }

            delete $self->{rooms}->{$resjid};
         }
      );

   $self->reg_cb (
      ext_after_created => sub {
         my ($self, $resjid, $mucjid) = @_;

         my $df = AnyEvent::XMPP::Util::DataForm->new;
         $df->set_type ('submit');
         my $sxl = $df->to_simxml;

         $self->{extendable}->send (new_iq (
            set =>
               src => $resjid,
               to => $mucjid,
            create => {
               node => {
                  dns => 'muc_owner',
                  name => 'query',
                  childs => [ $sxl ]
               }
            },
            cb => sub {
               my ($n, $e) = @_;

               if ($n) {
                  $self->event (entered => $resjid, $mucjid);

               } else {
                  $self->send_part ($resjid, $mucjid);
                  $self->event (error => $resjid, $mucjid, 'creation', $e);
               }
            }
         ));
      },
      ext_before_entered => sub {
         my ($self, $resjid, $mucjid) = @_;

         $self->{rooms}->{$resjid}->{$mucjid}->{joined} = 1;
      },
      ext_after_left => sub {
         my ($self, $resjid, $mucjid) = @_;
         $self->{pres}->clear_contact_presences ($resjid, $mucjid);
      }
   );

   $self->{pres}->reg_cb (
      generated_presence => sub {
         my ($pres, $node) = @_;
         my $resjid = $node->meta->{src};
         my $to     = prep_bare_jid $node->attr ('to');
         return unless defined $to;

         if (exists $self->{rooms}->{$resjid}
             && exists $self->{rooms}->{$resjid}->{$to}) {

            my $room = $self->{rooms}->{$resjid}->{$to};

            if ($room->{add_generated}) {
               $node->add (delete $room->{add_generated});
            }
         }
      },
   );
}

sub _join_jid_nick {
   my ($jid, $nick) = @_;
   my ($node, $host) = split_jid $jid;
   join_jid ($node, $host, $nick);
}

sub join {
   my ($self, $resjid, $mucjid, $nick, $password, $history) = @_;

   $resjid = stringprep_jid $resjid;

   my $myjid = _join_jid_nick ($mucjid, $nick);

   my @chlds;
   if (defined $password) {
      push @chlds, { name => 'password', childs => [ $password ] };
   }

   if (defined $history) {
      my $h;
      push @{$h->{attrs}}, ('maxchars', $history->{chars})
         if defined $history->{chars};
      push @{$h->{attrs}}, ('maxstanzas', $history->{stanzas})
         if defined $history->{stanzas};
      push @{$h->{attrs}}, ('seconds', $history->{seconds})
         if defined $history->{seconds};

      if (defined $h->{attrs}) {
         $h->{name} = 'history';
         push @chlds, $h;
      }
   }

   $self->{rooms}->{$resjid}->{prep_bare_jid $mucjid} = {
      my_jid => stringprep_jid ($myjid),
      join_args => [$password, $history],
      add_generated => { node => { dns => 'muc', name => 'x', childs => [ @chlds ] } }
   };

   $self->{pres}->send_directed ($resjid, $myjid, 1);
}

sub part {
   my ($self, $resjid, $mucjid, $timeout) = @_;

   $resjid = stringprep_jid $resjid;
   $mucjid = prep_bare_jid $mucjid;

   my $room = $self->{rooms}->{$resjid}->{$mucjid}
      or return;

   if (defined $timeout) {
      $self->{rooms}->{$resjid}->{$mucjid}->{part_timer} =
         AnyEvent->timer (after => $timeout, cb => sub {
            $self->event (left => $resjid, $mucjid);
            delete $self->{rooms}->{$resjid}->{$mucjid};
         });
   }

   $self->{rooms}->{$resjid}->{$mucjid}->{sent_part} = 1;

   my $pres = new_presence (
      unavailable => undef, undef, undef, src => $resjid, to => $room->{my_jid});
   $self->{extendable}->send ($pres);
}

sub handle_presence {
   my ($self, $resjid, $mucjid, $node, $old_pres) = @_;

   my $room = $self->{rooms}->{$resjid}->{$mucjid}
      or return;

   if (my $error = $node->meta->{error}) {

      if ($error->condition eq 'conflict') {
         my $nick = res_jid $room->{my_jid};
         $nick = $self->{nickcollision_cb}->($nick);
         $self->join ($resjid, $mucjid, $nick, @{$room->{join_args} || []});
         return;
      }

      $self->event (error => $resjid, $mucjid, 'presence', $error);
      return;
   }

   if (my ($x) = $node->find (muc_user => 'x')) {
      my %status_codes;

      for ($x->find (muc_user => 'status')) {
         $status_codes{$_->attr ('code')} = 1;
      }

      my $from = stringprep_jid $node->attr ('from');

      #d# warn "STATI: " . join (',', keys %status_codes) . "\n";

      if ($status_codes{210}) {
         $room->{my_jid} = $from;

      } elsif ($status_codes{201}) {
         $self->event (created => $resjid, $mucjid);

      } elsif ($status_codes{303}) {
         if (my ($item) = $x->find (muc_user => 'item')) {

            my $nick = $item->attr ('nick');

            if (defined $nick) {
               my $newjid = stringprep_jid _join_jid_nick ($mucjid, $nick);
               $room->{nick_changes}->{$newjid} = 1;

               if (cmp_jid ($room->{my_jid}, $from)) {
                  $room->{my_jid} = $newjid;
               }

               $self->event (nick_changed => $resjid, $mucjid, $from, $newjid);

            } else {
               warn "nick change without new nick: " . $node->raw_string;
            }

         } else {
            warn "nick change without new nick: " . $node->raw_string;
         }

      } elsif (delete $room->{nick_changes}->{$from}) {
         # ignore the presences after nick change

      } elsif (cmp_jid ($room->{my_jid}, $from)) {

         if ($room->{sent_part} # security check, so that if we part/join a heavily
                                # lagged room, so that the part timeout triggers,
                                # the lagged unavailable presence doesn't trigger
                                # a 'left' event before we got the 'entered' event.
                                # (this is so complicated that it will probably blow
                                # up on me...).
             && $node->attr ('type') eq 'unavailable') {

            $self->{rooms}->{$resjid}->{$mucjid}->{occs} = {};
            $self->event (left => $resjid, $mucjid);
            delete $self->{rooms}->{$resjid}->{$mucjid};

         } else {
            if (not (defined $old_pres) || $old_pres->{show} eq 'unavailable') {
               $self->{rooms}->{$resjid}->{$mucjid}->{occs}->{res_jid ($room->{my_jid})}
                  = {};
               $self->event (entered => $resjid, $mucjid);
            }
         }

      } elsif ($room->{joined}) {

         if ($node->attr ('type') eq 'unavailable') {
            delete $self->{rooms}->{$resjid}->{$mucjid}->{occs}->{res_jid ($from)};
            $self->event (parted => $resjid, $mucjid, $from);

         } else {
            if (not (defined $old_pres) || $old_pres->{show} eq 'unavailable') {
               $self->{rooms}->{$resjid}->{$mucjid}->{occs}->{res_jid ($from)}
                  = {};
               $self->event (joined => $resjid, $mucjid, $from);
            }
         }
      } else {
         $self->{rooms}->{$resjid}->{$mucjid}->{occs}->{res_jid ($from)} = {};
      }
   }
}

sub handle_message {
   my ($self, $resjid, $mucjid, $node) = @_;

   my $room = $self->{rooms}->{$resjid}->{$mucjid}
      or return;

   my $from = stringprep_jid $node->attr ('from');

   if ($node->meta->{error}) {
      my $muc_error = AnyEvent::XMPP::Error::Message->new (node => $node);
      $self->event (error => $resjid, $mucjid, 'message', $muc_error);

   } elsif ($node->attr ('type') eq 'groupchat') {
      my $msg_struct = {};
      extract_lang_element ($node, 'subject', $msg_struct);

      if (defined $msg_struct->{subject}) {
         $room->{subject} = {
            subject     => $msg_struct->{subject},
            all_subject => $msg_struct->{all_subject},
         };

         $self->event (subject_changed => $resjid, $mucjid, $from, $room->{subject});

      } else {
         if (cmp_jid ($from, $room->{my_jid})) {
            $self->event (message_echo => $resjid, $mucjid, $from, $node);

         } else {
            $self->event (message => $resjid, $mucjid, $from, $node);
         }
      }

   } else {
      $self->event (message_private => $resjid, $mucjid, $from, $node);
   }

   $self->{extendable}->stop_event;
}

sub get_rooms {
   my ($self, $resjid) = @_;

   $resjid = stringprep_jid $resjid;

   grep {
      $self->{rooms}->{$resjid}->{$_}->{joined} 
   } keys %{$self->{rooms}->{$resjid} || {}}
}

sub get_occupants {
   my ($self, $resjid, $mucjid) = @_;

   return unless exists $self->{rooms}->{$resjid};
   return unless exists $self->{rooms}->{$resjid}->{$mucjid};
   $self->{rooms}->{$resjid}->{$mucjid}->{occs}
}

sub joined_room {
   my ($self, $resjid, $mucjid) = @_;

   $resjid = stringprep_jid $resjid;
   $mucjid = prep_bare_jid $mucjid;

   exists $self->{rooms}->{$resjid} or return;
   exists $self->{rooms}->{$resjid}->{$mucjid} or return;
   $self->{rooms}->{$resjid}->{$mucjid}->{joined}
}

sub get_my_jid {
   my ($self, $resjid, $mucjid) = @_;

   $resjid = stringprep_jid $resjid;
   $mucjid = prep_bare_jid $mucjid;

   exists $self->{rooms}->{$resjid} or return;
   exists $self->{rooms}->{$resjid}->{$mucjid} or return;

   $self->{rooms}->{$resjid}->{$mucjid}->{my_jid}
}

=back

=head1 EVENTS

=over 4

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
