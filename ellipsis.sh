#!/usr/bin/env bash
#
# zeekay/dot-irssi
# My irssi configuration.

pkg.install() {
    ellipsis.backup $HOME/.irssi
    ln -s $PKG_PATH $HOME/.irssi
}
