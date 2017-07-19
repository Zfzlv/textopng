#!/usr/bin/perl

use strict;
use 5.010;
use warnings;
use utf8;
use Digest::MD5 qw( md5_hex );
use Encode;

my $image_dir = 'tex_image';


#################### main ####################

my $formulas_file = shift;
die 'Usage: find_missing.pl <formulas_file>' unless $formulas_file;

open my $fh, '<', $formulas_file;
while ( <$fh> ) {
	chomp;
	my $image_file = "$image_dir/" . ( md5_hex $_ ) . '.png';
	-s $image_file or say STDERR $_;
}
close $fh;
