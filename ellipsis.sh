#!/usr/bin/env bash
#
# zeekay/dot-irssi
# My irssi configuration.

pkg.install() {
    fs.link_file $PKG_PATH
}
