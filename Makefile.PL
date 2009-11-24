use strict;
use warnings;
use ExtUtils::MakeMaker;

print <<EOF;
Wellcome to AnyEvent::XMPP (version 1.x)
=========================================

 ************************** CAUTION **************************
 * This is 'AnyEvent::XMPP version 1.x' and the API is       *
 * completely incompatible to the previous 0.x versions.     *
 *                                                           *
 * The old versions are still available on CPAN:             *
 * http://search.cpan.org/CPAN/authors/id/E/EL/ELMEX/        *
 *************************************************************


EOF
sleep 3;

WriteMakefile(
    NAME                => 'AnyEvent::XMPP',
    AUTHOR              => 'Robin Redeker <elmex@ta-sa.org>',
    LICENSE             => 'perl',
    VERSION_FROM        => 'lib/AnyEvent/XMPP.pm',
    ABSTRACT_FROM       => 'lib/AnyEvent/XMPP.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'AnyEvent'           => 0,
        'AnyEvent::Socket'   => 0,
        'AnyEvent::Handle'   => 0,
        'Scalar::Util'       => 0,
        'MIME::Base64'       => 0,
        'Unicode::Stringprep'=> 0,
        'Authen::SASL'       => 0,
        'Digest::SHA1'       => 0,
        'Object::Event'      => 1.2,
        'Time::Local'        => 0,
        'common::sense'      => 0,
    },
    dist                => {
       COMPRESS => 'gzip -9f',
       SUFFIX => 'gz',
       PREOP => 'pod2text lib/AnyEvent/XMPP.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
    },
    clean               => { FILES => 'AnyEvent-XMPP-*' },
);
