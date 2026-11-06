#!/usr/bin/perl
# Load the app's MediaRemote bridge in the system Perl host.
use strict;
use warnings;
use DynaLoader;

my ($library, $mode, $position, $identifier) = @ARGV;
my $seek = defined($mode) && $mode eq '--seek';
die "usage: read-now-playing.pl LIBRARY [--once|--play|--pause|--previous|--next|--seek SECONDS CONTENT_ID]\n"
  unless defined($library) && ($seek
    ? @ARGV == 4 && defined($position) && $position =~ /\A\d+(?:\.\d+)?\z/ && $position <= 604800
      && defined($identifier) && length($identifier) > 0 && length($identifier) <= 4096
    : @ARGV <= 2 && (!defined($mode) || $mode =~ /\A--(?:once|play|pause|previous|next)\z/));
$ENV{AUGMA_NOW_PLAYING_POSITION} = $seek ? $position : '';
$ENV{AUGMA_NOW_PLAYING_CONTENT_IDENTIFIER} = $seek ? $identifier : '';
$ENV{AUGMA_NOW_PLAYING_ONCE} = defined($mode) && $mode eq '--once' ? '1' : '0';
my $control = defined($mode) && $mode ne '--once';
$ENV{AUGMA_NOW_PLAYING_COMMAND} = $control ? substr($mode, 2) : '';
my $handle = DynaLoader::dl_load_file($library, 0) or die "Cannot load the now-playing reader\n";
my $symbol = DynaLoader::dl_find_symbol($handle, $control ? 'augma_send_playback_command' : 'augma_observe_now_playing')
  or die "Cannot find the now-playing reader\n";
DynaLoader::dl_install_xsub('main::observe', $symbol);
main::observe();
