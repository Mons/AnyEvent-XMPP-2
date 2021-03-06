package AnyEvent::XMPP::Ext::Skel;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;
use AnyEvent::XMPP::Util qw/stringprep_jid new_iq new_reply/;
use Scalar::Util qw/weaken/;
use strict;
no warnings;

use base qw/AnyEvent::XMPP::Ext/;

=head1 NAME

AnyEvent::XMPP::Ext::Skel - Skeleton extension

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 DEPENDENCIES

This extension autoloads and requires the L<AnyEvent::XMPP::Ext::LangExtract>
extension.

=cut

sub required_extensions { 'AnyEvent::XMPP::Ext::LangExtract' } 

sub autoload_extensions { 'AnyEvent::XMPP::Ext::LangExtract' }

=head1 METHODS

=over 4

=cut

sub disco_feature { }

sub init {
   my ($self) = @_;

   $self->{iq_guard} = $self->{extendable}->reg_cb (
      recv_iq => sub { }
   );
}

=back

=head1 EVENTS

=over 4

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009, 2010 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
