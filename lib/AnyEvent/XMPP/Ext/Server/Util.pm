package AnyEvent::XMPP::Ext::Server::Util;

use common::sense;
use base 'Exporter';
our @EXPORT_OK = qw/arrxml/;

=head1 FUNCTIONS

=over 4

=item B<arrxml (\@xmlstruct)>

C<@xmlstruct> is hash-like, simple, ordered xml structure. For ex. vCard node may be generated so:

   simxml(
      node => {
         name => 'iq', attrs => [ type => 'result', from => $iq{from}, to => $iq{to}, id => $iq{id} ],
         childs => [{
            name => 'vCard', dns => 'vcard',
            childs => [
               arrxml([
                  FN => 'Mons Anderson',
                  NICKNAME => 'Mons',
                  N => [
                     FAMILY => 'Anderson',
                  ],
                  ORG => [
                     ORGNAME => 'Rambler Co.',
                  ],
                  PHOTO => [
                     TYPE => 'image/png',
                     BINVAL => $av,
                  ],
               ]),
            ],
         }],
      }
   )

C<arrxml> simply translates any pair of elements into simxml hash structure and invoke itself recursively 

Examples:

   arrxml [ key => 'value' ]
   #will give
   {
      name => 'key',
      childs => [ 'value' ]
   }

   arrxml [ key => [ inkey => 'value' ] ]
   #will give
   {
      name => 'key',
      childs => [
         {
            name => 'inkey',
            childs => [ 'value' ],
         }
      ]
   }

   arrxml [ key => { your => hash } ]
   #will give
   {
      name => 'key',
      childs => [
         { your => hash }
      ]
   }

See also C<AnyEvent::XMPP::Node::simxml>

=back

=cut

sub arrxml ($);
sub arrxml ($) {
	my $f= shift;
	ref $f eq 'ARRAY' or return $f;
	@$f or return;
	( map {+{
		name => $f->[$_*2],
		childs => [
			arrxml( $f->[$_*2+1] )
		],
	}} 0..int($#$f/2) ),
}

1;
