#!/bin/zsh

cd /Users/dlee/Project/Firefox/gecko2
datey=$(date '+%m%d%Y')
date=$(date '+%m%d')

backup="backup-$datey"
checkout="latest-$date"


git stash save $backup
git checkout -b $checkout --track origin/bookmarks/central

rm -rf obj-x86_64-*

./mach build
