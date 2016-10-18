##
## Based on https://github.com/stickster/irssi-libnotify
##

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1";
%IRSSI = (
	authors     => 'Hedede',
	contact     => 'Haddayn@gmail.com',
	name        => 'notify.pl',
	description => 'Displays desktop notifications when my name is mentioned.',
	license     => 'GNU General Public License v3',
	url         => '',
);


sub sanitize {
	my ($text) = @_;
	$text =~ s/\\/\\\\/g;
	$text =~ s/"/\\"/g;
	$text =~ s/\$/\\\$/g;
	$text =~ s/'/'"'"'/g;
	return $text;
}

sub notify_send {
	my ($server, $summary, $message) = @_;

	$summary = sanitize($summary);
	$message = sanitize($message);

	my $cmd = "EXEC notify-send '" . $summary . "' '" . $message . "'";
	$server->command($cmd);
}

sub match_nick {
	my ($nick) = @_;
	return $nick =~ /H[AUE]?DE?D(E|AYN)?/i;
}

sub match_mention_cyr {
	my ($nick) = @_;
	return $nick =~ /(хад(д)?)|(х(е)?д(е)?д(е)?)/i;
}

sub match_mention {
	my ($nick) = @_;
	return match_nick($nick) || match_mention_cyr($nick);
}

sub validate_sender {
	my ($sender) = @_;
	return $sender && !($sender=~/ctcp/) && !match_nick($sender);
}

sub print_text_notify {
	my ($dest, $text, $msg) = @_;
	my $server = $dest->{server};

	return if !$server;

	$msg =~ /^\<\W([^\>]+)\>.(.*)/;
	my $sender   = $1;
	my $stripped = $2;

	return if !validate_sender($sender);

	if (($dest->{level} & MSGLEVEL_HILIGHT) || match_mention($stripped) ) {
		my $summary = $sender . " (" . $dest->{target} . ")";
		notify_send($server, $summary, $stripped);
	}
}

sub ctcp_sound_notify {
	my ($server, $args, $nick, $addr, $target) = @_;

	$args =~ /^SOUND (.*\.wav.*)$/i;
	my $sound = $1;

	#unnecessary
	#return if match_nick($nick);

	if (match_mention($sound)) {
		my $summary = $nick . " (sound)";
		notify_send($server, $summary, $sound);
	}

}

sub message_private_notify {
	my ($server, $msg, $nick, $address) = @_;

	return if (!$server);
	notify_send($server, $nick . " (PM)", $msg);
}

sub dcc_request_notify {
	my ($dcc, $sendaddr) = @_;
	my $server = $dcc->{server};

	return if (!$dcc);
	notify_send($server, "DCC ".$dcc->{type}." request", $dcc->{nick});
}

Irssi::signal_add('print text', 'print_text_notify');
Irssi::signal_add('message private', 'message_private_notify');
Irssi::signal_add('dcc request', 'dcc_request_notify');
Irssi::signal_add("ctcp msg", "ctcp_sound_notify");

