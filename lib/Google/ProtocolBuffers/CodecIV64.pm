##
## Warning, despite name of the file, subrotines from here belongs
## to Google::ProtocolBuffers::Codec namespace
##
package Google::ProtocolBuffers::Codec;
use strict;

use warnings;
no warnings 'numeric';
use warnings FATAL => 'substr';
use Math::BigInt;

no warnings 'portable';
use constant MAX_UINT64 => 0xFFFF_FFFF_FFFF_FFFF;
use constant MAX_SINT64 => 0x7FFF_FFFF_FFFF_FFFF;
use constant MIN_SINT64 =>-0x8000_0000_0000_0000;

## Signature of all encode_* subs:
##      encode_*($buffer, $value);
## Encoded value of $value will be appended to $buffer, which is a string
## passed by reference. No meaningfull value is returned, in case of errors
## an exception it thrown.
## 
## Signature of all encode_* subs:
##      my $value = decode_*($buffer, $position);
## $buffer is a string passed by reference, no copy is performed and it
## is not modified. $position is a number variable passed by reference
## (index in the string $buffer where to start decoding of a value), it
## is incremented by decode_* subs. In case of errors an exception is
## thrown.

sub decode_varint {
    my $v = 0;  
    my $shift = 0;
    my $l = length($_[0]);
    while (1) {
        die BROKEN_MESSAGE() if $_[1] >= $l; 
        my $b = ord(substr($_[0], $_[1]++, 1));
        $v += (($b & 0x7F) << $shift);
        $shift += 7;
        last if ($b & 0x80)==0;
        die if $shift > 63;
    }
    return $v;
}

##
## Both signed and unsigned 32/64 ints are encoded by this sub.
## Must it be more restrictive and don't allow negative values for uint types?
## Moreover, should we check that the number is an integer and not a float, 
## for example? And truncate int32 types to 32 bits?
##
sub encode_int {
    if ($_[1]>=0) {
        encode_varint($_[0], $_[1]);
    } else {
        ## We need a positive 64 bit integer, which bit representation is
        ## the same as of this negative value, static_cast<uint64>(int64).
        ## unpack('Q', pack('q', $_[1])) is slightly slower than
        ## 2^64 + $v === (2^64-1) + $v + 1, for $v<0 
        encode_varint($_[0], (MAX_UINT64+$_[1])+1);
    }
}

sub decode_int {
    my $v = decode_varint(@_);
    if ($v>MAX_SINT64()) {
        return ($v-MAX_UINT64())-1;
    } else {
        return $v;
    }
}

##
## $_[1]<<1 is subject to overflow: a value that fit into 
## Perl's int (IV) may need unsigned int (UV) to fit,
## and I don't know how to make Perl do that cast.
##
sub encode_sint {
    if ($_[1]>=MAX_SINT64()) {
        encode_varint($_[0], Math::BigInt->new($_[1])<<1);
    } elsif ($_[1]<=MIN_SINT64) {
        encode_varint($_[0], ((-Math::BigInt->new($_[1]))<<1)-1);
    } elsif ($_[1]>=0) {
        encode_varint($_[0], $_[1]<<1);
    } else {
        encode_varint($_[0], ((-$_[1])<<1)-1);
    }
}

sub encode_fixed64 {
    $_[0] .= pack('V', $_[1] & 0xFFFF_FFFF);
    $_[0] .= pack('V', $_[1] >> 32);
}

sub decode_fixed64 {
    die BROKEN_MESSAGE() if $_[1]+8 > length($_[0]); 
    my $a = unpack('V', substr($_[0], $_[1],   4));
    my $b = unpack('V', substr($_[0], $_[1]+4, 4));
    $_[1] += 8;
    return $a | ($b<<32);
}

sub encode_sfixed64 {
    my $v = ($_[1]<0) ? (MAX_UINT64()+$_[1])+1 : $_[1]; 
    $_[0] .= pack('V', $v & 0xFFFF_FFFF);
    $_[0] .= pack('V', $v >> 32);
}

sub decode_sfixed64 {
    die BROKEN_MESSAGE() if $_[1]+8 > length($_[0]); 
    my $a = unpack('V', substr($_[0], $_[1],   4));
    my $b = unpack('V', substr($_[0], $_[1]+4, 4));
    $_[1] += 8;
    $a |= $b<<32;
    if ($a>MAX_SINT64()) {
        return ($a-MAX_UINT64())-1;
    } else {
        return $a;
    }
}



1;
