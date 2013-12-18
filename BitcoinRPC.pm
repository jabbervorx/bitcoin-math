package BitcoinRPC;

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use Carp;
use Sub::Name;

use vars qw{$AUTOLOAD};

sub new {
	my ($class, @args) = @_;
	my $obj = bless {
		lwp      => LWP::UserAgent->new(agent => 'BitcoinRPC 0.00000001'),
		host     => 'localhost',
		port     => '8332',
		user     => 'bitcoinrpc',
		password => 'bitcoin_password',
		@args
	  },
	  $class;
	$obj->{url} = "http://$obj->{host}:$obj->{port}/";
	$obj->{lwp}->credentials("$obj->{host}:$obj->{port}", 'jsonrpc', $obj->{user}, $obj->{password});
	$obj;
}

sub DESTROY { }

sub _call {
	my ($self, %args) = @_;
	my $content = encode_json({
			method => $args{method},
			params => $args{params},
			id     => rand
		}
	);
	my $resp = $self->{lwp}->post(
		$self->{url},
		Content_Type => 'application/json',
		Content      => $content,
		Accept       => 'application/json',
	);
	return decode_json($resp->decoded_content) if $resp && $resp->is_success;
	croak {error => "undefined response"} if not $resp;
	croak {error => "unsuccessful response: " . $resp->status_line};
}

sub AUTOLOAD {
	my $func = $AUTOLOAD;
	$func =~ s/.*:://;
	no strict 'refs';
	*{$func} = subname "$AUTOLOAD" => eval "sub { \$_[0]->_call(method => '$func', params => [\@_[1 .. \$#_]]) }";
	goto &$func;
}

1;
