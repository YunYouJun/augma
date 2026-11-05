#!/usr/bin/perl
# Load the app's read-only MediaRemote bridge in the system Perl host.
use strict;
use warnings;
use DynaLoader;

my ($library, $mode) = @ARGV;
die "usage: read-now-playing.pl LIBRARY [--once]\n"
  unless defined($library) && @ARGV <= 2 && (!defined($mode) || $mode eq '--once');
$ENV{AUGMA_NOW_PLAYING_ONCE} = defined($mode) ? '1' : '0';
my $handle = DynaLoader::dl_load_file($library, 0) or die "Cannot load the now-playing reader\n";
my $symbol = DynaLoader::dl_find_symbol($handle, 'augma_observe_now_playing')
  or die "Cannot find the now-playing reader\n";
DynaLoader::dl_install_xsub('main::observe', $symbol);
main::observe();
