#!/bin/bash

WRK_DIR=$(pwd)
if [ ! -d  tmp ]; then (mkdir tmp);fi
cd tmp; if [ ! -d  avatartools ]; then (git clone https://github.com/redsolution/avatartools.git); fi
cd avatartools && git checkout -q master
cd $WRK_DIR
if [ ! -d  priv ]; then (mkdir priv); fi
cp -r tmp/avatartools/images priv/
cp  tmp/avatartools/colors.json priv/colors.json
