package App::Tor;

use strict;
use warnings;

use File::Temp qw(mktemp);
use File::Tail;
use Carp qw(croak);
use LWP::UserAgent;
use Moo;
with 'MooX::Singleton';
use parent 'LWP::UserAgent';

has tor_client_pid => (
    is => 'rw',
);

has tor_client_binary => (
    is => 'ro',
);

has 'proxy_addr' => (
    is => 'lazy',
);

sub _build_proxy_addr { 'socks://localhost:9050' }


has 'kill_tor_client_on_exit' => (
    is => 'ro',
);

sub _get_tor_binary_path {
    my $self = shift;

    my $binary;
    if ($binary = $self->tor_client_binary ) {
        croak "got the binary path as object parameter but the file specified is invalid or isn't executable"
            unless -f $binary && -x $binary;

        return $binary;
    }
    elsif ($binary = $ENV{LWP_UA_TOR_CLIENT_BINARY_PATH}) {
        croak "got the binary path environment variable \$LWP_UA_TOR_CLIENT_BINARY_PATH  but the file specified is invalid or isn't executable"
            unless -f $binary && -x $binary;
        return $binary;
    }

    croak "neother LWP_UA_TOR_CLIENT_BINARY_PATH environment variable was set, nor tor_client_binary parameter provided to the object constructr";
}

sub ___build_tor_client {
    my ($binary,$tor_stdout_filename) = @_;


    # uh... 
    $SIG{CHLD}='IGNORE';

    my $pid = fork();

    if ( ! defined $pid ) {
        croak "Failed to fork the child process, sorry (erorr code: $!)";
    }

    return $pid if $pid;
    warn "tor stdout filename $tor_stdout_filename";
#    close STDIN; close STDOUT; close STDERR;
close STDOUT;
open STDOUT , '>>', $tor_stdout_filename;

    exec($binary, ("-Log","notice stdout")) or croak "Couldn't start the tor client :$!";
}

sub BUILD {
    my $self = shift;
warn "here";

    my $binary              = $self->_get_tor_binary_path();
    my $tor_stdout_filename = join "/", '/tmp', mktemp("tmpfileXXXXXXXXXX");

    $self->tor_client_pid(___build_tor_client($binary,$tor_stdout_filename));
    sleep 1 while ( ! -e $tor_stdout_filename );


    my $tail = File::Tail->new($tor_stdout_filename);
    while ( my $line = $tail->read() ) {
       # wait for the tor client to bootstrap itself
       last unless defined $line;
       last if $line =~ /Bootstrapped 100%: Done\.$/;
       warn "l";
    }

    warn "here123";

    unlink $tor_stdout_filename;

    return $self;
}

sub get_ua {
    my $self = shift;

    my $ua = LWP::UserAgent->new();
    $ua->proxy([qw(http https)] => $self->proxy_addr);

    return $ua;
}

sub DESTROY {
    my $self = shift;
    if ($self->tor_client_pid && $self->kill_tor_client_on_exit ) {
        kill -9, $self->tor_client_pid;
    }
}

1;

__END__

=head1  LWP::UserAgent::Tor

=head1 SYNOPSIS

my $ua = LWP::UserAgent::Tor->new();

my $res = $ua->post("http://173.194.34.68");


=head1 DESCRIPTION

do http over tor, start the tor client if needed
