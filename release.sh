#!/usr/bin/env sh

set -x -e

DIR=release/microphone
TAR=microphone.tar.gz

grunt build
mkdir -p $DIR
cp -r dist/* $DIR

cd $(dirname $DIR)

tar czvf $TAR $(basename $DIR)

cd -
rm -rf $DIR
