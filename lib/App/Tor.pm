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
        croak "I got the binary path environment variable \$LWP_UA_TOR_CLIENT_BINARY_PATH  but the file specified is invalid or isn't executable"
            unless -f $binary && -x $binary;
        return $binary;
    }

    croak "neither LWP_UA_TOR_CLIENT_BINARY_PATH environment variable was set, nor tor_client_binary parameter provided to the object constructr";
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
    close STDIN; close STDOUT; close STDERR;
    open STDOUT , '>>', $tor_stdout_filename;

    exec($binary, ("-Log","notice stdout")) or croak "Couldn't start the tor client :$!";
}

sub BUILD {
    my $self = shift;

    my $binary              = $self->_get_tor_binary_path();
    my $tor_stdout_filename = join "/", '/tmp', mktemp("tmpfileXXXXXXXXXX");

    $self->tor_client_pid(___build_tor_client($binary,$tor_stdout_filename));
    sleep 1 while ( ! -e $tor_stdout_filename );


    # wait here until the client bootstrapped
    my $tail = File::Tail->new($tor_stdout_filename);
    while ( my $line = $tail->read() ) {
       last unless defined $line;
       last if $line =~ /Bootstrapped 100%: Done\.$/;
    }

    unlink $tor_stdout_filename;

    return $self;
}

sub get_socket {
    my $self        = shift;
    my %socket_args = @_;
    my ($proxy_host,$proxy_port) = $self->proxy_addr =~ m[socks://(\w+):(\d+)];

    require IO::Socket::Socks;

    return IO::Socket::Socks->new(
       ProxyAddr => $proxy_host,
       ProxyPort => $proxy_port,
       %socket_args,
    );
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

=head1  App::Tor

=head1 SYNOPSIS

my $tor_client = App::Tor->new();
# now we have a tor client running in the backgroupd

my $ua = $tor->get_ua; # return LWP::UserAgent object, with the proxy settings predefined.
my $res = $ua->post("http://173.194.34.68");

my $socks5_socket = $tor->get_socket(%socket_args);


=head1 DESCRIPTION

set of utility functions for working with tor.



