# growl.pl - irssi script for growl notification

use strict;
use vars qw($VERSION %IRSSI);

$SIG{CHLD} = 'IGNORE';

$VERSION = '1.0.0';
%IRSSI = (
    authors     => 'zk',
    contact     => 'zeekayy@gmail.com',
    name        => 'growl',
    commands    => 'growl',
    description => 'Growl notifications for irssi'
);

use Irssi;
use MIME::Base64;

Irssi::settings_add_bool('growl', 'growl_sticky', 0);
Irssi::settings_add_bool('growl', 'growl_enabled', 1);
Irssi::settings_add_str('growl', 'growl_host', 'localhost');
Irssi::settings_add_str('growl', 'growl_path', '~/.irssi-growl/remote-notify.pl');
Irssi::settings_add_str('growl', 'growl_image', '~/.irssi-growl/img/irssi-white.png');

# help
sub show_help() {
    my $help = $IRSSI{name}." ".$VERSION.'
Simple script which uses growl to trigger notifications on highlight. It uses ssh to connect
to the computer running growl and uses remote-notify.pl to actually trigger the notification,
which passes the notification to growlnotify.
 
commands
  /growl                  Toggle growl notifications on/off.
  /growl sticky           Toggle sticky notifications on/off.
  /growl help             Display this help.

settings
  growl_enabled           Disable/Enable growl.
  growl_sticky            Make growl notfications sticky.      
  growl_host              Host to send growl notifications to.
  growl_path              Path to remote-notify.pl on remote host.
  growl_image             Path to image to you want growl to use.';

    print CLIENTCRAP $help;
}

# load settings
my $enabled = Irssi::settings_get_bool('growl_enabled');
my $sticky = Irssi::settings_get_bool('growl_sticky');
my $host = Irssi::settings_get_str('growl_host');
my $path = Irssi::settings_get_str('growl_path');
my $image = Irssi::settings_get_str('growl_image');

# toggle notifications on/off
sub toggle_growl {
    if ($enabled) {
        $enabled = 0;
        print CLIENTCRAP 'growl notifications disabled';
    } else {
        $enabled = 1;
        print CLIENTCRAP 'growl notifications enabled';
    }
}

# toggle notifications on/off
sub toggle_sticky {
    if ($sticky) {
        $sticky = 0;
        print CLIENTCRAP 'growl sticky notifications disabled';
    } else {
        $sticky = 1;
        print CLIENTCRAP 'growl sticky notifications enabled';
    }
}

# private message notify
sub priv_msg {
    my ($server, $text, $nick, $address) = @_;

    my $window = Irssi::active_win();
    my $msg_window = $server->window_find_item($nick);
    return unless ($window->{refnum} != $msg_window->{refnum});

    notify($nick, $text);
}

# hilight notify
sub hilight {
    my ($dest, $msg, $stripped) = @_;

    my $window = Irssi::active_win();
    my $msg_window = $dest->{window};
    return unless ($window->{refnum} != $msg_window->{refnum});
    
    if (($dest->{level} & MSGLEVEL_HILIGHT) && ($dest->{level} & MSGLEVEL_PUBLIC)) {
        my @values = split(' ', $stripped, 2);
        my ($nick, $text) = @values;
        $nick =~ s/[@&\[\]]//g;
        notify($nick, $text);
    }
}

# send notification to remote growl
sub notify {
    return unless ($enabled);

    # fork then do notification
    my $pid;
    $pid=fork();
    die "Cannot fork: $!" if (! defined $pid);
    if (! $pid) {
        # child process
        my ($nick, $text) = @_;
        $text =~ s/"/\\"/g;
    
        # construct args for notification
        my $args = "-n Irssi";
        if ($sticky) { $args = "$args -s"; }
        if ($image) { $args = "$args --image $image"; }
        $args = "$args -t $nick -m \"$text\"";
        my $enc = encode_base64($args);
        $enc =~ s/\R//g;
    
        exec('ssh', '-f', $host, $path, $enc);
        exit(0);
    }
}

# command dispatch
sub cmd_growl ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    if ($arg[0] eq 'help') {
        show_help();
    } elsif ($arg[0] eq 'sticky') {
        toggle_sticky();
    } else {
        toggle_growl();        
    }
}

# bind commands/signals
Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");
Irssi::command_bind('growl' => \&cmd_growl);

print CLIENTCRAP $IRSSI{name}.' '.$VERSION.' loaded: type /growl help for help';
