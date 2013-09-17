use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.1.0';
%IRSSI = (
	authors     => 'Roland Schilter, Thorsten Leemhuis',
	contact     => 'mail@rolandschilter.ch',
	name        => 'fnotify',
	description => 'Write a notification to a file that shows who is talking to you in which channel.',
	url         => 'http://github.com/rndstr/fnotify',
	license     => 'GNU General Public License',
	changed     => '$Date: 2010-04-16 13:00:00 +0100 (Fri, 16 Apr 2010) $'
);

#--------------------------------------------------------------------
# ChangeLog
# 2010-04-16 rs
#   Added more events: topic and public
#   Added settings to enable/disable logging of certain events
#     /set fnotify_topic (default Off)
#         Log topic changes
#     /set fnotify_private (default On)
#         Log private messages
#     /set fnotify_hilight (default On)
#         Log hilights
#     /set fnotify_public (default Off)
#         Log public messages
#     /set fnotify_public_channels
#         Log only for given channels (separated with comma or space)
#   
#--------------------------------------------------------------------
# Based on notify.pl 0.0.3 by Thorsten Leemhuis
# http://www.leemhuis.info/files/fnotify/
# that is based on knotify.pl 0.1.1 by Hugo Haas
# http://larve.net/people/hugo/2005/01/knotify.pl
# which is based on osd.pl 0.3.3 by Jeroen Coekaerts, Koenraad Heijlen
# http://www.irssi.org/scripts/scripts/osd.pl
#
# Other parts based on notify.pl from Luke Macken
# http://fedora.feedjack.org/user/918/
#--------------------------------------------------------------------


sub pub_msg {
  my ($server,$msg,$nick,$address,$target) = @_;
  $_ =  ' '.Irssi::settings_get_str('fnotify_public_channels').' ';
  if (Irssi::settings_get_bool('fnotify_public') and m/[, ]+\Q$target\E[, ]+/i) {
      filewrite($target.' <'.$nick.'> '.$msg);
  }
}

sub topic_msg {
  my ($server,$channel, $topic, $nick, $address) = @_;
  if (Irssi::settings_get_bool('fnotify_topic')) {
    filewrite($channel.' '.$topic);
  }
}


sub priv_msg {
  my ($server,$msg,$nick,$address,$target) = @_;
  if (Irssi::settings_get_bool('fnotify_private')) {
    filewrite($nick.' '.$msg);
  }
}

sub hilight {
  my ($dest, $text, $stripped) = @_;
  if ($dest->{level} & MSGLEVEL_HILIGHT && Irssi::settings_get_bool('fnotify_hilight')) {
    filewrite($dest->{target}.' '.$stripped);
  }
}


#--------------------------------------------------------------------
# The actual printing
#--------------------------------------------------------------------

sub filewrite {
  my ($text) = @_;
  # FIXME: there is probably a better way to get the irssi-dir...
  open(FILE,">>$ENV{HOME}/.irssi/fnotify");
  print FILE $text . "\n";
  close (FILE);
}



Irssi::signal_add_last('message public', 'pub_msg');
Irssi::signal_add_last('message private', 'priv_msg');
Irssi::signal_add_last('message topic', 'topic_msg');
Irssi::signal_add_last('print text', 'hilight');

Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'}.'_private', 1);
Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'}.'_hilight', 1);
Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'}.'_topic', 0);
Irssi::settings_add_bool($IRSSI{'name'}, $IRSSI{'name'}.'_public', 0);
Irssi::settings_add_str($IRSSI{'name'}, $IRSSI{'name'}.'_public_channels', ''); # e.g., '#one,#two,#three'

