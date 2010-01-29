package AnyEvent::XMPP::Ext::Server::VCard;

use strict;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;
use AnyEvent::XMPP::Node qw/simxml/;
use AnyEvent::XMPP::Util qw/new_presence bare_jid res_jid/;

use Object::Event 1.101;
use base qw/AnyEvent::XMPP::Ext/;

use AnyEvent::XMPP::Error::Presence;

sub disco_feature { ( xmpp_ns('vcard') ) }

sub init {
	my $self = shift;
	$self->{cb_id} = $self->{extendable}->reg_cb (
		ext_before_recv_iq => sub {
			my ($ext, $node) = @_;
			my %iq = map { $_ => $node->attr($_) } qw(id from to type);
			my $iqtype = $node->attr('type');
			warn "iq type = $iqtype";
			my $q;
			if (($q) = $node->find_all([qw/vcard vCard/])) {
				warn "vcard query $iqtype $iq{id}: $iq{from} => $iq{to}";
				#my %q = ( iq => \%iq, ( map { $_->name => $_->text } $q->nodes ) );
				$self->event( $iqtype => $q,$node, $node->attr('from'),$node->attr('to') )
					or warn("event <vcard.$iqtype> not handled"),return;
				$ext->stop_event;return 1;
			}
			return;
		},
	);
	return;
}

sub array2xml {
	my $f= shift;
	ref $f or return $f;
	@$f or return [];
	( map {+{
		name => uc($f->[$_*2]),
		childs => [
			array2xml( $f->[$_*2+1] )
		],
	}} 0..int($#$f/2) ),
}

sub vcard {
	my ($self,$node, $vc) = @_;
	
	my %iq = map { $_ => $node->attr($_) } qw(id from to type);
				$self->{extendable}->send(simxml(
					node => {
						name => 'iq', attrs => [
							type => 'result',
							from => $iq{to},
							to   => $iq{from},
							id   => $iq{id},
						],
						childs => [
							{
								name => 'vCard', dns => 'vcard',
								childs => [
									array2xml($vc),
								],
							}
						],
					}
				));
}

sub iq_fail {
	my ($self,$node,$type,$code,$name) = @_;
	#$type ||= 'cancel';
	#$code ||= 404;
	#$name ||= 'item-not-found';
	$type ||= 'error';
	$code ||= 406;
	$name ||= 'not-acceptable';
	my %iq = map { $_ => $node->attr($_) } qw(id from to type);
				$self->{extendable}->send(simxml(
					node => {
						name => 'iq', attrs => [
							type => $type,
							from => $iq{to},
							to   => $iq{from},
							id   => $iq{id},
						],
						childs => [
#<error code='406' type='modify'>
#   <not-acceptable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
#</error>
							$node->nodes,
							{ name => 'error', attrs => [ code => $code ], childs => [
								{ name => $name, dns => 'stanzas' }
							] }
						],
					}
				));
}

1;
