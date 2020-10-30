#!/bin/bash
VERSION=$(cat project.conf  | grep version | awk '{print $3}')
DESTDIR=${DESTDIR:-"/"}
PREFIX=${PREFIX:-"usr"}
BINDIR=${BINDIR:-"$PREFIX/bin"}
LIBDIR=${LIBDIR:-"$PREFIX/lib"}

install -vDm755 build/appctl -t $DESTDIR/$BINDIR/
install -vDm644 build/libapp.so $DESTDIR/$LIBDIR/libapp.so.$VERSION
ln -s libapp.so.$VERSION $DESTDIR/$LIBDIR/libapp.so

install -vDm644 build/librlxpkg -t $DESTDIR/$PREFIX/libexec/appctl/modules/