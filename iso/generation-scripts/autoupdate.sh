#!/bin/bash
# Script to automatically update the chroot and generate a new ISO
# This part to be ran inside the chroot
sorcery system-update
[[ -e caster ]] ||
  cd ${0%/*}
./caster -c basesystem # to get all cruft dispelled
./caster $(cat ../list.{reqd,all})
if [[ $ISOGEN_LOGFILE ]] ;then
  ./mk-smgl-iso &>$ISOGEN_LOGFILE
else
  ./mk-smgl-iso
fi
