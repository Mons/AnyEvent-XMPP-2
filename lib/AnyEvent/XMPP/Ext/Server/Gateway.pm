package AnyEvent::XMPP::Ext::Server::Gateway;

use strict;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;
use AnyEvent::XMPP::Node qw/simxml/;
use AnyEvent::XMPP::Util qw/new_presence bare_jid res_jid stringprep_jid node_jid/;

use base qw/AnyEvent::XMPP::Ext/;

use AnyEvent::XMPP::Error::Presence;

use Data::Dumper; $Data::Dumper::Useqq = 1;

sub array2xml {
	my $f= shift;
	ref $f or return $f;
	( map {+{
		name => $f->[$_*2],
		childs => [
			array2xml( $f->[$_*2+1] )
		],
	}} 0..int($#$f/2) ),
}

sub required_extensions { 'AnyEvent::XMPP::Ext::Disco', 'AnyEvent::XMPP::Ext::Presence' }
sub autoload_extensions { 'AnyEvent::XMPP::Ext::Disco', 'AnyEvent::XMPP::Ext::Presence' }
sub disco_feature { ( xmpp_ns('gateway'), xmpp_ns ('register') ) }

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

sub nextid {
	my $self = shift;
	return 'gw'.++$self->{id};
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
		#warn "found node $ns:$type: $q";
		return { iq => \%iq, ( map { $_->name => $_->text } $q->nodes ) };
	} else {
		return { iq => \%iq };
	}
}

sub disco { shift->{disco} }
sub reply_with_disco_info { shift->disco->reply_with_disco_info(@_) }
sub reply_with_disco_items { shift->disco->reply_with_disco_items(@_) }

sub init {
	my $self = shift;

	#$self->set_identity (client => console => 'AnyEvent::XMPP');
	$self->{id}     = 'aaaaa';
	$self->{fields} ||= [qw(username password)];
	$self->{name}   ||= $self->{extendable}{name} || 'AnyEvent::XMPP::Gateway';
	{
		local $self->{extendable} = "$self->{extendable}";
		#warn Dumper $self;
	}
	$self->{disco}  = $self->{extendable}->get_ext('Disco');
	$self->{disco}->unset_identity('client');

	$self->{disco}->set_identity('gateway', 'xmpp', $self->{name});
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
				warn "register query $iq{id}: $iq{from} => $iq{to}";
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
	$self->{extendable}->send( new_presence( probe => undef, undef , undef, src => $from, from => $from, to => $to) );
}

sub subscribe {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( subscribe => undef, undef , undef, src => $from, from => $from, to => $to) );
}

sub subscribed {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( subscribed => undef, undef , undef, src => $from, from => $from, to => $to) );
}

sub unsubscribe {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( unsubscribe => undef, undef , undef, src => $from, from => $from, to => $to) );
}

sub unsubscribed {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( unsubscribed => undef, undef , undef, src => $from, from => $from, to => $to) );
}

sub available {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( undef, 'online', undef , undef, src => $from,, from => $from, to => $to) );
}

sub unavailable {
	my $self = shift;
	my ($from,$to) = @_;
	$self->{extendable}->send( new_presence( unavailable => undef, undef , undef, src => $from, from => $from, to => $to) );
}

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
sub register_form {
	my $self = shift;
	my $node = shift;
	my $f = @_ ? [@_] : $self->{fields};
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
						{ name => 'instructions', childs => [
							$self->{instructions} || 'Please, fill the form below',
						] },
						(map {+{ name => $_ }} @$f),
					]
				}
			],
		}
	));
	return 1;
}

sub search_form {
	my $self = shift;
	my $node = shift;
	my $f = @_ ? [@_] : $self->{search_form};
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
						array2xml($f)
					]
				}
			],
		}
	));
	return 1;
}

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
	$self->{extendable}->send (new_presence (
		subscribe => undef, "Hi! Authorize me for correct work", undef, src => bare_jid($iq{to}), to => bare_jid($iq{from})));

}

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
	for (qw(unsubscribe unavailable)) {
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

sub roster_add {
	my $self = shift;
	my $user = shift;
	res_jid($user) or warn("Roster push on bare jid doesn't work"),return;
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
								name => 'item', attrs => [ jid => bare_jid($_->{jid}), name => $_->{name}, subscription => 'to', ],
								childs => [
									{ name => 'group', childs => [ $_->{group} || $self->{extendable}->jid ] },
								]
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
	res_jid($user) or warn("Roster push on bare jid doesn't work"),return;
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
	$self->unavailable( bare_jid($_->{jid}),bare_jid($user) ) for @_;
	#$self->contact_offline($user,$_) for @_;
}

1;
