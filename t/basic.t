use File::Temp;
use strict;
use Test::More tests => 1;
use warnings;

my ( $fh_, $filename ) = File::Temp::tempfile( UNLINK => 1, );

`MEMPROF=out_file=$filename perl -Ilib -d:MemProf t/foo.pl`;

my $out = do {
    local $/ = undef;
    open( my $fh, $filename ) or die $!;
    <$fh>;
};

$out =~ /main::foo\|(\d+)\|(\d+)/;
cmp_ok( $2 - $1, '>', 500_000, 'reported diff' );
