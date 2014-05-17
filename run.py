#!/usr/bin/env python
import getpass, os, re, subprocess, sys
from tempfile import mkstemp

# get znc_password securely
znc_password = getpass.getpass('znc password: ')
nickserv_password = getpass.getpass('nickserv password: ')

# read current config
with open(os.path.expanduser('~/.irssi/config')) as f:
    config = f.read()

# replace placeholder with real password
config = re.sub('ZNC_PASSWORD', znc_password, config)
config = re.sub('NICKSERV_PASSWORD', nickserv_password, config)

# store config in temporary file
fd, temp_config = mkstemp()
with open(temp_config, 'w') as f:
    f.write(config)

# run irssi
status = os.system('/usr/local/bin/irssi --config=%s' % temp_config)

# clean up
os.close(fd)
os.remove(temp_config)

# exit
sys.exit(status)
