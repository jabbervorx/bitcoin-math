package BitcoinRPC;

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;
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
	$obj->{lwp}->credentials("$obj->{host}:$obj->{port}", 'jsonrpc', $obj->{user}, $obj->{password})
	  if $obj->{lwp}->can("credentials");
	$obj;
}

sub DESTROY { }

sub _call {
	my ($self, $method, $params) = @_;
	my $resp = $self->{lwp}->request(
		POST $self->{url},
		Content_Type => 'application/json',
		Accept       => 'application/json',
		Content      => encode_json({
				method => $method,
				params => $params,
				id     => rand
			}
		)
	);
	return decode_json($resp->decoded_content) if $resp && $resp->is_success;
	croak "undefined response" if not $resp;
	croak "unsuccessful response: " . $resp->status_line;
}

sub AUTOLOAD {
	my $func = $AUTOLOAD;
	$func =~ s/.*:://;
	no strict 'refs';
	*{$func} = subname "$AUTOLOAD" => eval "sub { \$_[0]->_call('$func', [\@_[1 .. \$#_]]) }";
	goto &$func;
}

1;
