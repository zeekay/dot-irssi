pkg.install() {
    ellipsis.backup $HOME/.irssi
    ln -s $PKG_PATH $HOME/.irssi
}
