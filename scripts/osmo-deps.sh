#!/bin/sh

if ! test -d $1;
then
  git clone git://git.osmocom.org/$1 $1
fi

cd $1
git fetch origin
git reset --hard origin/master
