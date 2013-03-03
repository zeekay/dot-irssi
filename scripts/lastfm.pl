use vars qw($VERSION %IRSSI);
$VERSION = "5.6";
%IRSSI = (
        authors     => "Simon 'simmel' LundstrÃ¶m",
        contact     => 'simmel@(freenode|quakenet|efnet) http://last.fm/user/darksoy',
        name        => "lastfm",
        date        => "20100718",
        description => 'A now-playing-script which uses Last.fm',
        license     => "BSD",
        url         => "http://soy.se/code/",
);
Irssi::settings_add_str("lastfm", "lastfm_user", "");
Irssi::settings_add_str("lastfm", "lastfm_output", '%(%user is )np :: %artist-%name');
Irssi::settings_add_str("lastfm", "lastfm_output_tab_complete", '');
Irssi::settings_add_bool("lastfm", "lastfm_use_action", 0);
Irssi::settings_add_bool("lastfm", "lastfm_get_player", 0);

sub DEBUG {
  Irssi::settings_add_bool("lastfm", "lastfm_debug", 0);
  Irssi::settings_get_bool("lastfm_debug");
};

use strict;
use warnings;
use Data::Dumper;
use Encode;
use HTML::Entities;
use Irssi;
use LWP::UserAgent;
use POSIX;

my $pipe_tag;
my $api_key = "eba9632ddc908a8fd7ad1200d771beb7";
my $fields = "(artist|name|album|url|player|user)";
my $ua = LWP::UserAgent->new(agent => "lastfm.pl/$VERSION", timeout => 10);

sub lastfm_nowplaying {
  my ($content, $url, $response, $tag, $value, %data);
  my ($user_shifted, $is_tabbed, $nowplaying, $witem) = @_;
  my $user = $user_shifted || Irssi::settings_get_str("lastfm_user");
  $nowplaying ||= ((Irssi::settings_get_str("lastfm_output_tab_complete") ne "" && $is_tabbed) ? Irssi::settings_get_str("lastfm_output_tab_complete") : Irssi::settings_get_str("lastfm_output"));

  my $command_message = ($is_tabbed) ? '%%np(username)' : '/np username';
  if ($user eq '') {
    return "ERROR: You must /set lastfm_user to a username on Last.fm or use $command_message";
  }

  if ($nowplaying =~ /^%(lastfm|lfm)$/) {
    return "http://last.fm/user/$user/";
  }
  elsif ($nowplaying =~ /^%user$/) {
    return $user;
  }

  $data{'user'} = $user if ($user_shifted);

  $url = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=$user&api_key=$api_key&limit=1";
  print Dumper "Checking for scrobbles at: $url" if DEBUG;
  $response = $ua->get($url);
  $content = $response->content;

  # TODO This should work, untested (fail more Last.fm! ; )
  if ($content =~ m!<lfm status="failed">.*<error .*?>([^<]+)!s) {
    return "ERROR: $1";
  }
  my @data = split('\n', $content);

  #if (!grep(m!<track nowplaying="true">!, @data)) {
  #  print Dumper \$response if DEBUG;
  #  return "ERROR: You are not playing anything according to Last.fm. Check http://www.last.fm/user/$user and see if they turn up there, otherwise restart your scrobbler.";
  #}

  my $regex = qr!<$fields.*?(?:uts="(.*?)">.*?|>(.*?))</\1>!;

  foreach my $data (@data) {
    if ($data =~ m!</track>!) {
      last;
    }
    elsif ($data =~ /$regex/) {
      ($tag, $value) = ($1, (defined($2) ? $2 : $3));
      print Dumper \$tag, \$value, \$data if DEBUG;
      $data{$tag} = $value;
    }
  }

  if (Irssi::settings_get_bool("lastfm_get_player")) {
    $url = "http://www.last.fm/user/$user";
    $content = $ua->get($url)->content;
    if ($content =~ m!<span class="source">(.*?)</span>!) {
      $_ = $1;
      s/<[^>]*>//mgs;
      $data{'player'} = $_;
    }
    else {
      print "Couldn't find the player even though lastfm_get_player was set" if DEBUG;
    }
  }

  print Dumper \%data if DEBUG;
  print Dumper "Output pattern before: $nowplaying" if DEBUG;
  $nowplaying =~ s/(%\((.*?%(\w+).?)\))/($data{$3} ? $2 : "")/ge;
  print Dumper "Output pattern after: $nowplaying" if DEBUG;
  $nowplaying =~ s/%$fields/$data{$1}/ge;
  decode_entities($nowplaying);
  Encode::from_to($nowplaying, "utf-8", Irssi::settings_get_str("term_charset"));
  return $nowplaying;
}

sub lastfm_blocking {
  my ($witem, $user) = @_;
  my $nowplaying = lastfm_nowplaying($user, undef, undef, $witem);
  lastfm_print($witem, $nowplaying);
}

sub lastfm_forky {
  my ($witem, $user) = @_;
  # pipe is used to get the reply from child
  my ($rh, $wh);
  pipe($rh, $wh);

  # non-blocking host lookups with fork()ing
  my $pid = fork();
  if (!defined($pid)) {
    Irssi::print("Can't fork() - aborting");
    close($rh);
    close($wh);
    return;
  }

  if ($pid > 0) {
    # parent, wait for reply
    close($wh);
    Irssi::pidwait_add($pid);
    $pipe_tag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, [$witem, $rh]);
    return;
  }

  my $text;
  eval {
    # child, do the lookup
    $text = lastfm_nowplaying($user);
  };

  if (!$text) {
    $text = "ERROR: Error message: $!";
  }

  eval {
    # write the reply
    print($wh $text);
    close($wh);
  };
  POSIX::_exit(1);
}


sub pipe_input {
  my ($witem, $rh) = @{$_[0]};
  my $text = <$rh>;
  close($rh);

  Irssi::input_remove($pipe_tag);
  $pipe_tag = -1;

  lastfm_print($witem, $text);
}

sub lastfm_print {
  my ($witem, $text, $tabbed) = @_;
  # Fugly error handling
  if ($text =~ s/^ERROR: //) {
    Irssi::active_win()->print($text);
    return;
  }

  if ($tabbed) {
    return $text;
  }
  elsif (defined $witem->{type} && $witem->{type} =~ /^QUERY|CHANNEL$/) {
    if (Irssi::settings_get_bool("lastfm_use_action")) {
      $witem->command("me $text");
    }
    else {
      $witem->command("say $text");
    }
  }
  else {
    Irssi::active_win()->print($text);
  }
}

Irssi::command_bind('lf', sub {
    my ($data, $server, $witem) = @_;
    $data =~ s/ .*//;
    $data ||= 0;
    if (DEBUG) {
      lastfm_blocking($witem, $data);
    }
    else {
      lastfm_forky($witem, $data);
    }
  }, 'lastfm');

Irssi::signal_add_last 'complete word' => sub {
  my ($complist, $window, $word, $linestart, $want_space) = @_;
  my $is_tabbed = 1;
  my $tab_fields = $fields;
  $tab_fields =~ s/\(/(nowplaying|np|lastfm|lfm|/;
  if ($word =~ /(\%(?:$tab_fields))\(?(\w+)?\)?/) {
    my ($nowplaying, $user) = ($1, $3);
    undef $nowplaying if ($nowplaying =~ /nowplaying|np/);
    $nowplaying = lastfm_nowplaying($user, $is_tabbed, $nowplaying);
    if (lastfm_print(Irssi::active_win(), $nowplaying, 1)) {
      push @$complist, "$nowplaying";
    }
  }
};

