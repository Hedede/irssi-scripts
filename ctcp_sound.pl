##
## Based on PGGB_sound script by Adam Duck (duck@cs.uni-frankfurt.de)
##

use strict;
use utf8;
use vars qw($VERSION %IRSSI);

$VERSION = "1";
%IRSSI = (
	  authors       => 'Hedede',
	  contact       => 'Haddayn@gmail.com',
	  name          => 'hudds_ctcp_sound',
	  description   => 'Allows to play CTCP sounds.',
	  license       => 'GNU General Public License v3',
	  url           => '',
	 );

my $defhome = $ENV{HOME} . '/.irssi';
Irssi::settings_add_bool('PGGB', 'SOUND_autosend',  1);
Irssi::settings_add_bool('PGGB', 'SOUND_autoget',   0);
Irssi::settings_add_bool('PGGB', 'SOUND_play',      1);
Irssi::settings_add_int( 'PGGB', 'SOUND_display',   5);
Irssi::settings_add_str( 'PGGB', 'SOUND_hilight',   '(none)');
Irssi::settings_add_str( 'PGGB', 'SOUND_DCC',       '(none)');
Irssi::settings_add_str( 'PGGB', 'SOUND_dir',       $defhome . '/sounds');
Irssi::settings_add_str( 'PGGB', 'SOUND_command',   'play -q');
my $autoget = Irssi::settings_get_bool("SOUND_autoget");

########################################

use File::Basename;
use File::Find;

Irssi::command_bind("wav",   "sound_command");
Irssi::command_bind("ss",    "stop_sounds");
Irssi::signal_add_last("complete word", "sound_complete");
Irssi::signal_add("event privmsg", "sound_autosend");
Irssi::signal_add("ctcp msg", "CTCP_sound");
Irssi::signal_add('print text', 'hilight_sound');
Irssi::signal_add('dcc created', 'DCC_sound');
#IRC::add_message_handler("PRIVMSG", "sound_autoget");


Irssi::theme_register([ 'ctcp', '{ctcp {hilight $0} $1}' ]);

sub help {
	Irssi::print("USAGE: /wav <soundname>(.wav)?\n");
	Irssi::print("Please setup all variables through the /SET command (they all begin with \"SOUND_\").");
}

sub find_wave {
	my $sounddir = Irssi::settings_get_str("SOUND_dir");
	my $sound    = shift(@_);
	$sound = quotemeta($sound);
	unless ($sound =~ /^.*\.wav$/i) {
		$sound = $sound . ".*.wav";
	}

	my @files = glob($sounddir . '/*.wav');
	my $result = [];

	for (@files) {
		my $fName = $_;
		if (basename($fName) =~ /^$sound$/i) {
			push @$result, $fName;
		}
	}

	#print join(", ", @$result);

	return @$result;
}

sub onoff { shift(@_) ? return "ON" : return "OFF"; }

sub play_sound {
	my ($wavfile) = @_;
	my $soundcmd = Irssi::settings_get_str("SOUND_command");
	my $playcmd = system("$soundcmd \"$wavfile\" 2>/dev/null &");
}

sub stop_sounds {
	my ($data, $server, $witem) = @_;
	my $channel = $witem->{name};
	my $soundcmd = Irssi::settings_get_str("SOUND_command");
	my $killed = `pkill -cf \"$soundcmd\"`;
	$server->command("/action $channel killed $killed sounds");
};

sub sound_command {
	my $sounddir = Irssi::settings_get_str("SOUND_dir") . "/";

	my ($data, $server, $witem) = @_;

	$data =~ /([\S]+)(..*)?/;
	my $sound       = $1;
	my $rest        = $2;
	$rest =~ s/ *//;

	if ($sound =~ /(.*)\.wav/i) {
		$sound = $1;
	}

	$rest = $sound if ($rest eq "");
	$rest = " " . $rest;
	$sound .= ".wav";

	if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
		my $wavefile = (find_wave($sound))[0];
		if ( -r $wavefile ) {
			$witem->command("/CTCP $witem->{name} SOUND ".lc(basename($wavefile))."$rest");
			play_sound($wavefile);
		} else {
			$witem->print("\"$sound\" is not found in \"$sounddir\".");
		}
	} else {
		Irssi::print "There's no point in running a \"CTCP SOUND\" command here.";
	}
	return 1;
}

sub sound_complete {
	my ($complist, $window, $word, $linestart, $want_space) = @_;
	if ($linestart =~ /^\/wav$/) {
		my $coli = [];
		my @wavs = find_wave($word);
		for (find_wave($word)) { push(@$coli, basename($_)); }
		my $max = Irssi::settings_get_int('SOUND_display');
		if (@$coli > $max) {
			$window->print("@$coli[0..($max-1)] ...");
		} else {
			push @$complist, @$coli;
		}
	}
}

sub sound_autosend {
  if (!Irssi::settings_get_bool("SOUND_autosend")) { return 0; }
  my ($server, $data, $nick, $address) = @_;
  my $myname = $server->{nick};

  $data =~ /(.*) :!$myname +(.*\.wav)/i;
  if ($2 eq "") { return 0; }
  my $channel	= $1;
  my $wavefile	= (find_wave($2))[0];
  if ($wavefile ne "") {
    Irssi::print("DCC sending $wavefile to $nick");
    $server->command("/DCC SEND $nick $wavefile");
  } else {
    $server->send_message($nick, "Sorry, $nick. $2 not found.", 1);
  }
  return 1;
}

sub hilight_sound {
  my ($dest, $text, $stripped) = @_;
  my $server = $dest->{server};
  unless ($server->{usermode_away}) {
    my $hiwave = Irssi::settings_get_str('SOUND_hilight');
    if (($hiwave ne '(none)') &&
	($dest->{level} & (MSGLEVEL_HILIGHT|MSGLEVEL_MSGS)) &&
	($dest->{level} & MSGLEVEL_NOHILIGHT) == 0) {
      play_wave(find_wave($hiwave));}}}

sub DCC_sound {
  my $dcc = shift(@_);
  my $server = $dcc->{server};
  Irssi::print("$dcc->{type}");
  unless ($server->{usermode_away} || ($dcc->{type} eq "SEND")) {
    my $hiwave = Irssi::settings_get_str('SOUND_DCC');
    if ($hiwave ne '(none)') {
      play_wave(find_wave($hiwave));}}}

sub play_wave {
  my $wave = shift(@_);
  my $sndcmd = Irssi::settings_get_str("SOUND_command");
  if (-r "$wave") {
    system("$sndcmd \"$wave\" 2>/dev/null &");}}

sub sound_autoget {
  if (!$autoget) { return 0; }
  my $sounddir	= Irssi::settings_get_str("SOUND_dir") . "/";

  my $line = shift (@_);
  #:nick!host PRIVMSG channel :message
  $line =~ /:(.*)!(\S+) PRIVMSG (.*) :(.*)/i;

  my $name = $1;
  my $channel = $3;
  my $text = $4;
  my $name = "$name";
  my @wordlist = split(' ',$4);

  if ($wordlist[0] eq "\001SOUND") {
    my $tempsound = $wordlist[1];
    $tempsound =~ s/[\r \001 \n]//;
    IRC::print($tempsound);
    if (!open(TEMPFILE, "<", $sounddir.$tempsound)) {
      IRC::send_raw("PRIVMSG $name :!$name $tempsound\r\n");
    } else {
      close(TEMPFILE);
    }
  }
  return 0;
}

sub CTCP_sound {
	my $play     = Irssi::settings_get_bool("SOUND_play");
	my $soundcmd = Irssi::settings_get_str("SOUND_command");

	my ($server, $args, $nick, $addr, $target) = @_;
	$args =~ /^SOUND (.*\.wav)(.*)$/i;
	if ($1 eq "") { return 0; }

	my $sound   = $1;
	my $rest    = $2;
	$rest =~ s/^ *//;

	my $output = "";
	$output .= "[" . $rest . "] " if ( $rest ne "" );
	$output .= $sound;

	my $wavfile = (find_wave($sound))[0];
	if ( -r $wavfile ) {
		if ($play) {
			play_sound($wavfile);
		} else {
			$output .= " (muted)";
		}
	} else {
		$output .= " (not found)";
		if ($autoget) {
			Irssi::send_raw("PRIVMSG $nick :!$nick $sound\r\n");
		}
	}

	# TODO: compare with receiver (i.e. me) instead of #
	if ( substr($target, 0, 1) ne '#' )
	{
		$target = $nick;
	}

	my $wItem = $server->window_find_item($target);
	if ($wItem) {
		$wItem->printformat(MSGLEVEL_CTCPS, 'ctcp', $nick, $output);
	} else {
		Irssi::print "Can't find window $target.";
		Irssi::printformat(MSGLEVEL_CTCPS, 'ctcp', $nick, $output);
	}
	Irssi::signal_stop();
}
