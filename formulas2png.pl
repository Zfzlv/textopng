#!/usr/bin/perl

use strict;
use 5.010;
use warnings;
use utf8;
use Digest::MD5 qw( md5_hex );
use Encode;

my $default_chunk_size = 1;
my $image_dir = 'tex_image';

binmode \*STDOUT, ':utf8';
binmode \*STDERR, ':utf8';


#################### main ####################

my $formulas_file = shift;
my $chunk_size = shift;
$chunk_size = $default_chunk_size if ( !defined $chunk_size );

die 'Usage: formulas2png <formulas_file>' unless $formulas_file;

-d $image_dir or mkdir $image_dir;

map { unlink $_ } glob '*.png';

# gen $chars
say STDERR 'Finding all mbox characters...';
my %chars = ( '占' => undef );
open my $fh, '<:utf8', $formulas_file;
while ( <$fh> ) {
	chomp;
	map { $chars{$_} = undef } ( $_ =~ m/[^\x20-\x7F]/g );
}
my $chars = join '', keys %chars;
close $fh;

# convert by chunk
say STDERR 'Starting convertion by chunk...';
my $seq = 0;
my @formula_chunk;
my $chunk_start = 1;
open TXT,">a.txt";
open $fh, '<', $formulas_file;
while ( 1 ) {
	my $formula = <$fh>;
	if ( defined $formula ) {
		++$seq;
		chomp $formula;
		my $image_file = "$image_dir/" . ( md5_hex $formula ) . '.png';
		print TXT $formula."\t".( md5_hex $formula ) . '.png'."\n";
		push @formula_chunk, $formula if !-f $image_file;
	}
	if ( 0 == $seq % $chunk_size || !defined $formula ) {
		&formulas2png ( $chunk_start, @formula_chunk );
		@formula_chunk = ( );
		$chunk_start = $seq + 1;
		say STDERR "Done $seq ...";
	}
	last if !defined $formula;
}
close $fh;
close TXT;
# &formulas2png <$chunk_start> <@formula_chunk>
sub formulas2png {
	my $chunk_start = shift;
	my @formula_chunk = @_;

	return unless @formula_chunk;

	open my $tex_fh, '>:utf8', 'zs.tex';
	print $tex_fh <<END;
\\documentclass{article}
\\usepackage{CJKutf8}
\\usepackage{amssymb}
\\usepackage{amsmath}
\\usepackage{wasysym}
\\begin{document}
\\begin{CJK*}{UTF8}{gbsn}
\\newcommand{\\ROOT}[2]{\\sqrt[#1]{#2}}

END
	for ( @formula_chunk ) {
		my $f = decode_utf8 $_;
		say $tex_fh "% $chunk_start: $f";
		++$chunk_start;

		# filter exeptions
		$f =~ s/^\{\&nbs个;\}\^\{\{\&nbs个;\}\^\{\&nbs个;\}\}$/./;
		$f =~ s/^\\stackrel\{\}\{\}$/./;
		$f =~ s/^\\stackrel\{ \}\{ \}$/./;
		$f =~ s/^\{ \}\^\{ \}_\{ \}$/./;
		$f =~ s///g;
		$f =~ s/﹙﹚/\\left(\\right)/g;
		$f =~ s/([$chars]+)/\\mbox{$1}/g;
		$f =~ s/^_$/\\underline{\\ }/;
		$f =~ s/_{2,}/\\underline{\\ \\ \\ }/g;
		$f =~ s//\\ /g;
		$f =~ s/root/ROOT/g;
		$f =~ s/\\&\w*;?/\\ /g;
		$f =~ s/([%#])/\\$1/g;
		$f =~ s/(?<=\{)_|_(?=\})|^_/\\underline{\\ }/g;
		$f =~ s/(?<=\{)\^|\^(?=\})|^\^/\\land/g;
		$f =~ s/\\right\}/\\right\\}/g;
		$f =~ s/ /\\ /g; # this is \xc2a0, not space
		$f =~ s/\\\\\[/\\\\{}[/g;
		$f =~ s/(\\permil)\b/\\mbox{$1}/g;

		say $tex_fh "\$\$$f\$\$";
	}
	print $tex_fh <<END;

\\end{CJK*}
\\end{document}
END
	close $tex_fh;

	system ( 'latex \'\makeatletter\def\HCode{\futurelet\HCode\HChar}\def\HChar{\ifx"\HCode\def\HCode"##1"{\Link##1}\expandafter\HCode\else\expandafter\Link\fi}\def\Link#1.a.b.c.{\g@addto@macro\@documentclasshook{\RequirePackage[#1,html]{tex4ht}}\let\HCode\documentstyle\def\documentstyle{\let\documentstyle\HCode\expandafter\def\csname tex4ht\en^Csname{#1,html}\def\HCode####1{\documentstyle[tex4ht,}\@ifnextchar[{\HCode}{\documentstyle[tex4ht]}}}\makeatother\HCode\' \'.a.b.c.\input\' zs.tex >/dev/null 2>&1 </dev/null' ) and return;
	system ( 'tex4ht zs.tex >/dev/null 2>&1 </dev/null' ) and return;
	for ( 1 .. @formula_chunk ) {
		system ( "dvipng -T tight -x 2800 -D 72 -bg Transparent -pp $_:$_ zs.idv -o zs@{[ $_ - 1 ]}x.png >/dev/null 2>&1" ) and return;
	}

	my @png_files = glob 'zs[0-9]*x.png';

	if ( @png_files != @formula_chunk ) {
		map { unlink $_ } glob '*.png';
		say STDERR 'png files mismatch with formulas.';
	}

	my $i = 0;
	for ( @formula_chunk ) {
		rename "zs${i}x.png", "$image_dir/" . ( md5_hex $_ ) . '.png';
		++$i;
	}
}
