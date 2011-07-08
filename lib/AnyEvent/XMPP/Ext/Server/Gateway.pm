package AnyEvent::XMPP::Ext::Server::Gateway;

use strict;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;
use AnyEvent::XMPP::Node qw/simxml/;
use AnyEvent::XMPP::Ext::Server::Util qw/arrxml/;
use AnyEvent::XMPP::Util qw/new_presence bare_jid res_jid stringprep_jid node_jid/;

use base qw/AnyEvent::XMPP::Ext/;

use AnyEvent::XMPP::Error::Presence;

=head1 NAME

AnyEvent::XMPP::Ext::Server::Gateway - XEP-0100: Gateway Interaction

=head1 SYNOPSIS


   my $client = AnyEvent::XMPP::Stream::Component->new(
      domain => $domain,
      secret => $secret,
      name   => $title,
   );
   my $gw = $client->add_ext('Server::Gateway');
   
   $gw->reg_cb(
      request => sub { # Register query request (iq type get, query jabber:iq:register)
         my ($gw,$query,$iq) = @_;
         return $gw->iq_fail($iq,403) unless $registration_allowed;
         if ($not_reg{ $iq->attr('from') }) {
            $gw->register_form($iq, [
               instructions => 'Enter your login and password',
               username     => [],
               password     => [],
            ]);
         } else {
            $gw->registered($iq, [
               username => 'known-username',
               password => 'stored-password',
            ]);
         }
      },
      register => sub { # Register query request (iq type set, query jabber:iq:register)
         my ($gw,$query,$iq,$fields) = @_;
         return $gw->iq_fail($iq,403) unless $registration_allowed;
         if ($fields->{username} and $fields->{password}) {
            if (correct($fields)) {
               $gw->register_ok($iq);
            } else {
               $gw->iq_fail($iq, 406);
            }
         } else {
            $gw->iq_fail($iq, 406);
         }
      },
      unregister => sub { # Unregister query request (iq type set, query jabber:iq:register, remove)
         my ($gw,$query,$iq) = @_;
         if (registered{$iq->attr('from')}) {
            unregister($iq->attr('from'));
            $gw->unregister_ok($iq);
            if (@roster) {
               $gw->roster_del($iq->attr('from'), @roster);
            }
         } else {
            $gw->iq_fail($iq, 406);
         }
      },
      search => sub { # Search prompt from client (iq type get, query jabber:iq:gateway)
         my ($gw,$query,$iq) = @_;
         $gw->search_form($iq,
            desc => 'Enter user email in domain @somewhere.com',
            prompt => "Email",
         );
      },
      translate => sub { # Translate legacy username to gateway jid (iq type set, query jabber:iq:gateway)
         my ($gw,$query,$iq,$fields) = @_;
         my $legacy = $fields->{prompt};
         if (ok($legacy)) {
            $gw->translated( $iq, $legacy .'@'. $gw->jid ); # return translated legacy login to jid
         } else {
            $gw->iq_fail($iq);
         }
      },
      roster => sub { # Roster change request (iq type set, query jabber:iq:roster)
         my ($gw,$query,$iq,$change) = @_;
         # TODO
         return $gw->iq_fail($iq, 406);
      },
   );
   
   # Also, if need in vcard support feel free to add
   $client->add_ext('Server::VCard');
   
   Additionaly, service discovery requests may be intercepted
   
   $gw->reg_cb(
      discovery_items => sub {
         my ($gw,$query,$node) = @_;
         return $gw->iq_fail($node,403) unless $discovery_allowed;
         $gw->reply_with_disco_items($node);
      },
      discovery_info => sub {
         my ($gw,$query,$node) = @_;
         return $gw->iq_fail($node,403) unless $discovery_allowed;
         $gw->reply_with_disco_info($node);
      },
   );


=head1 DESCRIPTION

This extension implements xep-0100 Gateway interaction

=head1 DEPENDENCIES

This extension autoloads and requires the L<AnyEvent::XMPP::Ext::Disco> extension.

=head1 EVENTS

=over 4

=item request ($query_node, $iq_node) # get register query

=item register ($query_node, $iq_node, \%fields )

=item unregister ($query_node, $iq_node)

=item search ($query_node, $iq_node)  ->  $gw->search_form($iq,{desc,prompt})

=item translate ($query_node, $iq_node, \%fields)  ->  $gw->translated( $iq, $legacy );

=item roster($query_node, $iq_node, { remove => [{jid}, ...],  })


=item discovery_info ($query_node, $iq_node)

=item discovery_items ($query_node, $iq_node)

=back

=head1 PRESENCE EVENTS

This component have own presence handling. Presences separated in 2 groups:
presences addressed to component itself (prefix=C<gateway>)
and presences to contacts in component domain (prefix=C<contact>)

Presence type is defined as C<type> attribute of presence stansa and defaults to C<presence>,
if attribute is omitted

C<Gateway> will try to find presence event handler by next chain:

   ${prefix}_${type}
   any_${prefix}_presence
   ${prefix}_presence
   any_presence


=over 4

=item gateway_${type} ($node,$from)

=item contact_${type} ($node,$from,$to)

=item any_* ( $node, $type, $from, $to )

=back

So, you may as write separate event handlers for every single type of presence, as use only one handler for all presences

If presence was not handled and it was subscribe, adressed to gateway itself (C<gateway_subscribe>),
gateway will automatically respond with C<subscribed>

Simple example

   $gw->get_cb(
      any_presence => sub {
         my ($gw,$node,$type,$from,$to) = @_;
         # Generic handler for all presences
      },
   );

Separate gateway and contact presences

   $gw->get_cb(
      any_gateway_presence => sub {
         my ($gw,$node,$type,$from) = @_;
         # Generic handler for all gateway presences
      },
      any_contact_presence => sub {
         my ($gw,$node,$type,$from,$to) = @_;
         # Generic handler for all contact presences
      },
   );

Complex handlers with any_gateway_* fallback

   $gw->get_cb(
      gateway_subscribed => sub {
         my ($gw,$node,$from) = @_;
      },
      gateway_unsubscribe => sub {
         my ($gw,$node,$from) = @_;
         $gw->unsubscribed($gw->jid => $from);
      },
      gateway_unsubscribed => sub {
         my ($gw,$node,$from) = @_;
      },
      gateway_presence => sub {
         my ($gw,$node,$from,$new) = @_;
         if ($new->{show} eq 'unavailable') {
            # Log out from gateway
            $gw->unavailable( $gw->jid => $from );
         } else {
            # Log in to gateway
            return $gw->available( $self->jid => $from );
         }
      },
      gateway_probe => sub {
         my ($gw,$node,$from) = @_;
         # may reply with presences for all contact list
      },
      any_gateway_presence => sub {
         my ($node,$type,$from) = @_;
         warn "Unhandled presence of type $type from $from";
      },
      any_contact_presence => sub {
         my ($node,$type,$from,$to) = @_;
         # Generic handler for all contact presences
         # Retransmit any contact presence to legacy service
      },
   );

=head1 METHODS

=over 4

=cut

use Data::Dumper; $Data::Dumper::Useqq = 1;

sub array2xml {
	my $f= shift;
	ref $f or return $f;
	@$f or return [];
	( map {+{
		name => $f->[$_*2],
		childs => [
			array2xml( $f->[$_*2+1] )
		],
	}} 0..int($#$f/2) ),
}

sub required_extensions { 'AnyEvent::XMPP::Ext::Disco' }
sub autoload_extensions { 'AnyEvent::XMPP::Ext::Disco' }
sub disco_feature { ( xmpp_ns('gateway'), xmpp_ns ('register') ) }

=for remove
sub set_instructions {
	my $self = shift;
	$self->{instructions} = shift;
}

sub instructions {
	shift->{instructions}
}

sub set_fields {
	my $self = shift;
	$self->{fields} = ref $_[0] ? shift : [@_];
}

sub fields {
	shift->{fields}
}

=cut

sub nextid {
	my $self = shift;
	return 'gw-'.++$self->{id};
}

# COPYPAST! vvv
sub _to_pres_struct {
   my ($node) = @_;
   my %struct;

   my (@show)   = $node->find_all ([qw/stanza show/]);
   my (@prio)   = $node->find_all ([qw/stanza priority/]);

   $struct{jid}      = $node->attr ('from');
   $struct{show}     =
      @show
         ? $show[0]->text
         : (($node->attr('type') || '' ) eq 'unavailable' ? 'unavailable' : 'available');
   $struct{priority}   = @prio ? $prio[0]->text : 0;
   $struct{status}     = $node->meta->{status};
   $struct{all_status} = $node->meta->{all_status};
   \%struct
}
# COPYPAST! ^^^

sub iq_hash {
	my $node = shift;
	my ($ns,$type) = @_;
	my %iq = map { $_ => $node->attr($_) } qw(id from to type);
	my $q;
	if (($q) = $node->find($ns,$type)) {
		return { iq => \%iq, ( map { $_->name => $_->text } $q->nodes ) };
	} else {
		return { iq => \%iq };
	}
}

sub disco { shift->{disco} }
sub reply_with_disco_info { shift->disco->reply_with_disco_info(@_) }
sub reply_with_disco_items { shift->disco->reply_with_disco_items(@_) }

=item jid

return component's jid. just a proxy to extendable->jid

=cut

sub jid { shift->{extendable}->jid }

sub init {
	my $self = shift;

	#$self->set_identity (client => console => 'AnyEvent::XMPP');
	$self->{id}     = 'aaaaa';
	$self->{fields} ||= [qw(username password)];
	$self->{type}   ||= 'xmpp';
	warn "create ext $self with type $self->{type}";
	$self->{name}   ||= $self->{extendable}{name} || 'AnyEvent::XMPP::Gateway';
	$self->{disco}  = $self->{extendable}->get_ext('Disco');
	$self->{disco}->unset_identity('client');

	$self->{disco}->set_identity('gateway', $self->{type}, $self->{name});
	$self->{disco}->{cb_id} = $self->{extendable}->reg_cb (
		ext_before_recv_iq => sub {
			my ($ext, $node) = @_;
			if ($node->attr ('type') eq 'get') {
				my ($q);
				if (($q) = $node->find (disco_info => 'query')) {
					my $from = bare_jid($node->attr('from'));
					if ($self->handles('discovery_info')) {
						$self->event('discovery_info' => $q, $node );
						$ext->stop_event;return 1;
					} else {
						#return $self->iq_fail($node,403);
						$self->{disco}->reply_with_disco_info ($node);
					}
				}
				elsif (($q) = $node->find (disco_items => 'query')) {
					warn "Discovery items";
					if ($self->handles('discovery_items')) {
						$self->event('discovery_items' => $q, $node );
						$ext->stop_event;return 1;
					} else {
						$self->{disco}->reply_with_disco_items ($node);
					}
				}
			}
		}
	);

	$self->{cb_id} = $self->{extendable}->reg_cb (
		recv_presence => 510 => sub {
			my ($ext, $node) = @_;
			#$self->_analyze_stanza ($node);

			my $meta   = $node->meta;
			my $resjid = $meta->{dest};

			return if $meta->{error};

			my $from   = stringprep_jid $node->attr ('from');
			my $to     = stringprep_jid $node->attr ('to');
			#warn "Got presence from $from";

			$to = $resjid unless defined $to;
			$to = $self->{extendable}->jid unless defined $to;

			unless (defined (node_jid $to) || defined (node_jid $from)) {
				warn "$resjid: Ignoring badly addressed presence stanza: "
					  . $node->raw_string . "\n";
				return;
			}
			my $myjid = $self->{extendable}->jid;
			if ($to eq $myjid or $to =~ /^(.+)\@\Q$myjid\E$/) {
				my ($prefix,$user);
				my @args = ($node,$from);
				if ($user = $1) {
					#warn "Received presence to my user <$user>\n";
					$prefix = 'contact';
					push @args, $to;
				} else {
					$prefix = 'gateway';
				}
				# Destination is gateway
					my $type   = $node->attr ('type');
				if ($meta->{presence}) {
					push @args, _to_pres_struct( $node );
					if ($type) {
						#warn "received meta.presence with type $type";
					} else {
						$type = 'presence';
					}
					
				}
					if ($self->handles("${prefix}_${type}")) {
						$self->event( "${prefix}_${type}" => @args );
							#or warn("event <${prefix}_${type}> not handled"),return;
					}
					elsif ($self->handles("any_${prefix}_presence")) {
						unshift @args,$type;
						$self->event( "any_${prefix}_presence" => @args );
						#	and $ext->stop_event,return 1;
					}
					elsif ($self->handles("${prefix}_presence")) {
						$self->event( "${prefix}_presence" => @args );
						#	and $ext->stop_event,return 1;
					}
					elsif ($self->handles('any_presence')) {
						unshift @args, $type;
						$self->event( "any_presence" => @args );
						#	and $ext->stop_event,return 1;
					}
					elsif ($type eq 'subscribe' and !$user) {
						$self->subscribed($to, $from);
					}
					else {
						warn("event <gw.${prefix}_${type}> not handled"),return;
					}
			}
			else {
				warn("Malformed to:$to, should be ".$self->{extendable}->jid.", ignoring");
				return;
			}
			$ext->stop_event;return 1;
		},
		ext_before_recv_iq => sub {
			my ($ext, $node) = @_;
			my %iq = map { $_ => $node->attr($_) } qw(id from to type);
			my $iqtype = $node->attr('type');
			#warn "iq type = $iq{type}";
			my $q;
			if ($iqtype eq 'get' and ($q) = $node->find_all([qw/register query/])) {
				$self->event( request => $q, $node )
					or warn("event <gateway.request> not handled"),return;
				$ext->stop_event;return 1;
			}
			elsif ($iqtype eq 'set' and ($q) = $node->find_all([qw/register query/])) {
				if ($q->find(qw(register remove))) {
					#warn "unregister query $iq{id} set: $iq{from} => $iq{to} (+$q)";
					$self->event( unregister => $q, $node )
						or warn("event <gateway.unregister> not handled"),return;
				} else {
					#warn "register query $iq{id} set: $iq{from} => $iq{to} (+$q)";
					my %fields = ( map { $_->name => $_->text } $q->nodes );
					$self->event( register => $q, $node, \%fields )
						or warn("event <gateway.register> not handled"),return;
				}
				$ext->stop_event;
				return 1;
			}
			if ($iqtype eq 'get' and ($q) = $node->find_all([qw/gateway query/])) {
				#warn "gateway query $iq{id}: $iq{from} => $iq{to}";
				$self->event( search => $q, $node )
					or warn("event <gateway.search> not handled"),return;
				$ext->stop_event;return 1;
			}
			if ($iqtype eq 'set' and ($q) = $node->find_all([qw/gateway query/])) {
				my %fields = ( map { $_->name => $_->text } $q->nodes );
				warn "gateway query $iq{id}: $iq{from} => $iq{to} $fields{prompt}";
				$self->event( translate => $q, $node, \%fields )
					or warn("event <gateway.translate> not handled"),return;
				$ext->stop_event;return 1;
			}
			if ($iqtype eq 'set' and ($q) = $node->find_all([qw/roster query/])) {
				warn "gateway query $iq{id}: roster update";
				my %change;
				for ($q->nodes) {
					push @{ $change{ $_->attr('subscription')} ||= [] }, { jid => $_->attr('jid') };
				}
				$self->event( roster => $q,$node,\%change )
					or warn("event <gateway.roster> not handled"),return;
				$ext->stop_event;return 1;
			}
			return;
		},
	);
	return;
}

sub probe {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( probe => undef, undef , undef, src => $from, from => $from, to => $to, id => $self->nextid ) );
}

sub subscribe {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( subscribe => undef, undef , undef, src => $from, from => $from, to => $to, id => $self->nextid) );
}

sub subscribed {
	my $self = shift;
	warn "Call subscribed from @{[ (caller)[1,2] ]}";
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( subscribed => undef, undef , undef, src => $from, from => $from, to => $to, id => $self->nextid) );
}

sub unsubscribe {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( unsubscribe => undef, undef , undef, src => $from, from => $from, to => $to, id => $self->nextid) );
}

sub unsubscribed {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( unsubscribed => undef, undef , undef, src => $from, from => $from, to => $to, id => $self->nextid) );
}

sub available {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( undef, 'online', undef , undef, src => $from,, from => $from, to => $to, id => $self->nextid) );
}

sub unavailable {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( unavailable => undef, undef , undef, src => $from, from => $from, to => $to, id => $self->nextid) );
}

=item registered($iq, $form)

send a registered response to register query. C<$iq> is request iq node

   $gw->registered($iq, [
      username => 'known-username',
      password => 'stored-password',
   ]);

=cut

sub registered {
	my $self = shift;
	my $node = shift;
	my $f =
		ref $_[0] ?
			ref $_[0] eq 'HASH' ? [ %{$_[0]} ] :
			[ @{$_[0]} ] :
		[ @_ ];
				$self->{extendable}->send(simxml(
					node => {
						name => 'iq', attrs => [
							type => 'result',
							from => $node->attr('to'),
							to   => $node->attr('from'),
							id   => $node->attr('id'),
						],
						childs => [
							{
								name => 'query', dns => 'register',
								childs => [
									{ name => 'registered' },
									@$f ? ( map {+{
										name => $f->[$_*2],
										childs => [ $f->[$_*2+1] ],
									}} 0..int($#$f/2) ) : (),
								]
							}
						],
					}
				));
	return 1;
	
}

=item register_form($iq, $form)

send a register form response to register query. C<$iq> is request iq node

   $gw->register_form($iq, [
      instructions => 'Please, fill the form below',
      username     => [],
      password     => [],
   ]);

=cut

sub register_form {
	my $self = shift;
	my $node = shift;
	my $f = shift;
	#my $f = @_ ? [@_] : $self->{fields};
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'result',
				from => $node->attr('to'),
				to   => $node->attr('from'),
				id   => $node->attr('id'),
			],
			childs => [
				{
					name => 'query', dns => 'register',
					childs => [
						arrxml($f),
						#{ name => 'instructions', childs => [
						#	$self->{instructions} || 'Please, fill the form below',
						#] },
						#(map {+{ name => $_ }} @$f),
					]
				}
			],
		}
	));
	return 1;
}

=item search_form($iq, $form)

send a search form response to gateway search query prompt. C<$iq> is request iq node

   $gw->search_form($iq, [
      desc => 'Enter user email in domain @somewhere.com',
      prompt => "Email",
   ]);

=cut

sub search_form {
	my $self = shift;
	my $node = shift;
	#my $f = @_ ? [@_] : $self->{search_form};
	my $f = @_ > 1 ? [@_] : shift;
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'result',
				from => $node->attr('to'),
				to   => $node->attr('from'),
				id   => $node->attr('id'),
			],
			childs => [
				{
					name => 'query', dns => 'gateway',
					childs => [
						arrxml($f)
					]
				}
			],
		}
	));
	return 1;
}

=item translated($iq, $jid)

send a reply to gateway translate query. C<$iq> is request iq node

   $gw->translated($iq, $legacy.'@'.$gw->jid);

=cut

sub translated {
	my $self = shift;
	my $node = shift;
	my $tran = shift;
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'result',
				from => $node->attr('to'),
				to   => $node->attr('from'),
				id   => $node->attr('id'),
			],
			childs => [
				{
					name => 'query', dns => 'gateway',
					childs => [
						{
							name => 'jid', childs => [ $tran ],
						}
					]
				}
			],
		}
	));
	return 1;
}

=item register_ok($iq)

send a reply to register query. C<$iq> is request iq node. Also sends subscribe presence, as required by xep

   $gw->register_ok($iq);

=cut

sub register_ok {
	my ($self,$node) = @_;
	my %iq = map { $_ => $node->attr($_) } qw(id from to type);
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'result',
				from => $iq{to},
				to   => $iq{from},
				id   => $iq{id},
			],
		}
	));
	#$self->{pres}->send_subscription_request(
	#	bare_jid($iq{to}) => bare_jid($iq{from}),
	#	1, "Hi! Authorize me for correct work",
	#);
	#$self->{extendable}->send (new_presence (
	#	subscribe => undef, "Hi! Authorize me for correct work", undef, src => bare_jid($iq{to}), to => bare_jid($iq{from})));

}

=item unregister_ok($iq)

send a reply to unregister query. C<$iq> is request iq node. Also sends unsubscribe and unavailable presences

   $gw->unregister_ok($iq);

=cut

sub unregister_ok {
	my ($self,$node) = @_;
	my %iq = map { $_ => $node->attr($_) } qw(id from to type);
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'result',
				from => $iq{to},
				to   => $iq{from},
				id   => $iq{id},
			],
		}
	));
	for (qw(unsubscribe unsubscribed unavailable)) {
	#for (qw(unsubscribe unsubscribed unavailable)) {
		my $p = new_presence( $_ => undef, undef, undef, src => $iq{to} );
		$p->attr( to => $iq{from} );
		$self->{extendable}->send($p);
	}
}

# http://xmpp.org/extensions/xep-0086.html
our %ERR = ( 
	302 => [ 'gone',                    'modify', 'Redirect' ],
	400 => [ 'bad-request',             'modify', 'Bad Request'],
	401 => [ 'not-authorized',          'auth',   'Not Authorized'],
	402 => [ 'payment-required',        'auth',   'Payment Required'],
	403 => [ 'forbidden',               'auth',   'Forbidden'],
	404 => [ 'item-not-found',          'cancel', 'Not Found' ],
	405 => [ 'not-allowed',             'cancel', 'Not Allowed' ],
	406 => [ 'not-acceptable',          'modify', 'Not Acceptable' ],
	407 => [ 'registration-required',   'auth',   'Registration Required' ],
	408 => [ 'remote-server-timeout',   'wait',   'Request Timeout' ],
	409 => [ 'conflict',                'cancel', 'Conflict' ],
	500 => [ 'internal-server-error',   'wait',   'Internal Server Error' ],
	501 => [ 'feature-not-implemented', 'cancel', 'Not Implemented' ],
	502 => [ 'service-unavailable',     'wait',   'Remote Server Error' ],
	503 => [ 'service-unavailable',     'cancel', 'Service Unavailable' ],
	504 => [ 'remote-server-timeout',   'wait',   'Remote Server Timeout' ],
	510 => [ 'service-unavailable',     'cancel', 'Disconnected' ],
);

=item iq_fail($iq, [ $code ])

send an error reply to any incoming iq. By default send 406, not-acceptable.

C<$code> referenced from L<http://xmpp.org/extensions/xep-0086.html>

   $gw->unregister_ok($iq);

=cut


sub iq_fail {
	my ($self,$node,$code) = @_;
	$code ||= 406;
	my ($name,$type) = @{ $ERR{$code} };
	$name ||= 'not-acceptable';
	my %iq = map { $_ => $node->attr($_) } qw(id from to type);
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'error',
				from => $iq{to},
				to   => $iq{from},
				id   => $iq{id},
			],
			childs => [
				{ name => 'error', attrs => [ code => $code, type => $type, ], childs => [
					{ name => $name, dns => 'stanzas' }
				] }
			],
		}
	));
}

sub iq_result {
	my ($self,$iq) = @_;
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'result',
				from => $iq->attr('to'),
				to   => $iq->attr('from'),
				id   => $iq->attr('id'),
			],
		}
	));
}

sub roster_add {
	my $self = shift;
	my $user = shift;
	res_jid($user) or $self->{no_warn_roster_bare} or warn("Roster push on bare jid may not work");
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'set',
				to   => $user,
				id   => $self->nextid,
			],
			childs => [
				{
					name => 'query', dns => 'roster',
					childs => [
						map {
							{
								name => 'item', attrs => [ jid => bare_jid($_->{jid}), name => $_->{name}, subscription => $_->{subscription} || 'to', ],
								exists $_->{group} ? (
									childs => [
										{ name => 'group', childs => [ $_->{group} ] },
									]
								) : (),
							}
						} @_
					]
				}
			]
		}
	));
	for my $item (@_) {
		$self->subscribed( bare_jid($item->{jid}),bare_jid($user) );
		#my $p = new_presence( ('subscribed')x2 );
		#$p->attr( from => bare_jid($item->{jid}) );
		#$p->attr( to => bare_jid($user) );
		#$self->{extendable}->send($p);
		if ($item->{online}) {
			$self->available( bare_jid($item->{jid}),bare_jid($user) );
			#$self->contact_online($user,$item);
		}
	}

}

sub contact_online {
	my $self = shift;
	my $user = shift;
	for my $item (@_) {
		my $p = new_presence( ('available')x2, 'online' );
		$p->attr( from => bare_jid($item->{jid}) );
		$p->attr( to => bare_jid($user) );
		$self->{extendable}->send($p);
	}
}

sub contact_offline {
	my $self = shift;
	my $user = shift;
	for my $item (@_) {
		my $p = new_presence( ('unavailable')x2, 'offline' );
		$p->attr( from => bare_jid($item->{jid}) );
		$p->attr( to => bare_jid($user) );
		$self->{extendable}->send($p);
	}
}

sub roster_del {
	my $self = shift;
	my $user = shift;
	res_jid($user) or $self->{no_warn_roster_bare} or warn("Roster push on bare jid may not work");
	$self->{extendable}->send(simxml(
		node => {
			name => 'iq', attrs => [
				type => 'set',
				to   => $user,
				id   => $self->nextid,
			],
			childs => [
				{
					name => 'query', dns => 'roster',
					childs => [
						map {
							{
								name => 'item', attrs => [ jid => bare_jid($_->{jid}), subscription => 'remove', ],
							}
						} @_
					]
				}
			]
		}
	));
	#$self->unavailable( bare_jid($_->{jid}),bare_jid($user) ) for @_;
	#$self->contact_offline($user,$_) for @_;
}

=back

=cut

1;
