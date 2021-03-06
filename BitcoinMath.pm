package BitcoinMath;

use strict;
use warnings;
use Crypt::Digest qw(digest_data digest_data_hex);

our @base58 = ('1' .. '9', 'A' .. 'H', 'J' .. 'N', 'P' .. 'Z', 'a' .. 'k', 'm' .. 'z');

sub reverse_map {
	my @ret;
	for (my $i = 0; $i < @base58; ++$i) {
		$ret[ord($base58[$i])] = $i;
	}
	@ret;
}

our @decBase58 = reverse_map;

sub big_zero {use bigint; 0}

sub decodeBase58 {
	my $base58 = $_[0];
	my $return = big_zero;
	for (my $i = 0; $i < length($base58); $i++) {
		my $sym = ord(substr($base58, $i, 1));
		$return *= 58;
		$return += $decBase58[$sym];
	}
	$return = lc substr($return->as_hex, 2);
	for (my $i = 0; $i < length($base58) && substr($base58, $i, 1) eq "1"; $i++) {
		$return = "00" . $return;
	}
	if (length($return) % 2 != 0) {
		$return = "0" . $return;
	}
	return $return;
}

sub encodeBase58 {
	my $orighex = $_[0];
	die "encodeBase58: uneven number of hex characters" if length($orighex) % 2 != 0;
	my $hex = big_zero;
	for (my $i = 0; $i < length($orighex); ++$i) {
		$hex = $hex * 16 + hex(substr($orighex, $i, 1));
	}
	my $return = "";
	for (; $hex > 0; $hex /= 58) {
		$return .= $base58[$hex % 58];
	}
	$return = reverse($return);
	for (my $i = 0; $i < length($orighex) && substr($orighex, $i, 2) eq "00"; $i += 2) {
		$return = "1" . $return;
	}
	return $return;
}

sub checksum {
	return lc unpack 'H8', digest_data("SHA256", digest_data("SHA256", pack 'H*', $_[0]));
}

sub checkBitcoinAddress {
	local $_ = shift;
	die 'wrong format' unless /^[@base58]{34,}$/x;
	$_ = decodeBase58 $_;
	my $checksum = checksum sprintf '%042s', substr $_, 0, -8;
	die 'wrong checksum' unless m{$checksum$};
}

sub hash160ToAddress {
	my ($hash, $version) = ($_[0], (sprintf '%02x', $_[1] || 0));
	local $_ = sprintf '%34s', map encodeBase58($_ . checksum($_)), $version . $hash;
	tr/ /1/;
	return $_;
}

sub hash160 {
	my $data = pack("H*", $_[0]);
	return lc(digest_data_hex("RIPEMD160", digest_data("SHA256", $data)));
}

sub addressToHash160 {
	my $addr = decodeBase58($_[0]);
	$addr = substr($addr, 2, length($addr) - 10);
	return $addr;
}

sub pubKeyToAddress {
	return hash160ToAddress(hash160($_[0]));
}

sub generateKeyAddressPair {
	my $mode;
	my %sd;
	for (`openssl ecparam -genkey -name secp256k1 -noout |openssl ec -text 2>/dev/null`) {
		chomp;
		if    (/^priv:/) {$mode = "priv"; next}
		elsif (/^pub:/)  {$mode = "pub";  next}
		elsif (/^\S/)    {$mode = ""}
		if ($mode) {s/[\s:]//g; $sd{$mode} .= uc $_}
	}
	$sd{priv} = '80' . $sd{priv} if $sd{priv} !~ s/^00/80/;
	return (encodeBase58($sd{priv} . checksum($sd{priv})), pubKeyToAddress($sd{pub}));
}

1;
