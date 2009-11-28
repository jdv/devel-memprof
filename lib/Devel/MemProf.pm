package Devel::MemProf;

=head1 NAME

Devel::MemProf - Memory profiling

=head1 VERSION

0.01

=cut

our $VERSION = '0.01';

package DB;

use 5.008;
use IO::Handle;
use strict;
use warnings;

=head1 SYNOPSIS

perl -d:MemProf foo.pl

=head1 DESCRIPTION

This started out as a copy of jrockway's Devel::MProf but morphed when I
needed it to find a memory leak.  The idea is the same and that is to report
memory usage increase as measured around all sub calls.  This version has a
few additional features including:  delta threshold, consolidated listing,
and stack trace for anonymous subs.

=head1 CONFIGURATION AND ENVIRONMENT

There are several package variables available for config.
They can be set directly at runtime:

 $DB::delta = 1_000_000;
 $DB::mprof = 0;

or before via the MEMPROF environment variable:

 MEMPROF=delta=1_000_000:mprof=0 perl -d:MemProf foo.pl

=over

=item $DB::delta

Memory diff threshold in bytes.  Default is 100K.

=item $DB::mprof

Flag to toggle profiling on or off.  Default is 1.

=item $DB::consolidate

Flag to toggle listing consolidation on or off.  Default is 1.
When $consolidate is false output is the raw listing.

=item $DB::trace

Flag to toggle stack traces on anonymous subs on or off.
Default is 1.  Note this is only available if $consolidate is true.

=item $DB::out_file

Filename for output.  Default is mprof.out.

=back

=cut

our $delta = 100_000;
our $mprof = 1;
our $consolidate = 1;
our $trace = 1;
our ( $mem_prev, $mem_cur, ) = ( '', );
our $out_file = 'mprof.out';

if ( $ENV{ 'MEMPROF' } ) {
    for ( split( /:/, $ENV{ 'MEMPROF' } ) ) {
        my @pair = split( /=/, $_ );
        $pair[ 1 ] = "'$pair[ 1 ]'" unless $pair[ 1 ] =~ /^\d+$/;
        eval "\$DB::$pair[ 0 ]=$pair[ 1 ]";
    }
}

open( my $stat, '<', "/proc/$$/stat" ) or die "failed to open stat: $!";
open( my $out, '>', $out_file ) or die "failed to open mprof.out: $!";
$out->autoflush( 1 );

sub DB {}

END { $mprof = 0; }

sub sub {
    no strict 'refs';

    return &{ $DB::sub } unless $mprof;

    my $before;
    if ( $mprof ) {
        seek( $stat, 0, 0 ) or die "seek failed";
        <$stat> =~ /\) (.*)$/;
        $before = ( split( /\s/, $1 ) )[ 20 ];
    }

    my @ret;
    unless ( wantarray ) {
        $ret[ 0 ] = &{ $DB::sub };
    }
    else {
        @ret = &{ $DB::sub };
    }

    if ( $mprof ) {
        seek( $stat, 0, 0 ) or die "seek failed";
        <$stat> =~ /\) (.*)$/;
        my $after = ( split( /\s/, $1 ) )[ 20 ];
        if ( $delta < $after - $before ) {
            if ( $consolidate ) {
                $mem_cur = "$before|$after";
                unless ( $mem_prev eq $mem_cur ) {
                    print $out "\n";
                    print $out join( '|', $DB::sub, $before, $after, );
                    if ( $trace && substr( $DB::sub, 0, 4, ) eq 'CODE' ) {
                        my $i = 0;
                        while ( my @call = ( caller( $i++ ) )[ 0 .. 3 ] ) {
                            print $out "\n  " . join( '|', @call );
                        }
                    }
                    print $out "\n";
                }
                $mem_prev = $mem_cur;
            }
            else {
                print $out join( '|', $DB::sub, $before, $after, );
                print $out "\n";
            }
        }
    }

    return wantarray ? @ret : $ret[ 0 ];
}

=head1 AUTHOR

Justin DeVuyst, C<justin@devuyst.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Justin DeVuyst.

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
