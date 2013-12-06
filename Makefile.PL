use strict;
use warnings;

use 5.010001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'App::Tor',
    VERSION_FROM      => 'lib/App/Tor.pm',
    PREREQ_PM         => {
        'LWP::UserAgent'       => 0,
        'LWP::Protocol::socks' => 0,
        Moo                    => 0,
        'File::Tail'           => 0,
        'File::Temp'           => 0,
        'MooX::Singleton'      => 0,
        'IO::Socket::Socks'    => 0,

    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/App/Tor.pm',
       AUTHOR         => 'A. U. Thor <tjmc@localdomain>') : ()),
);
