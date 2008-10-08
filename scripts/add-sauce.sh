#!/bin/bash

TEMPDIR="/tmp/sauce.$$"

FORCE=false
if [[ $1 == "-f" ]] ;then
  shift
  FORCE=true
fi

TYPE=bad
if [[ $1 == "-i" ]] ;then
  TYPE=iso
elif [[ $1 == "-s" ]] ;then
  TYPE=system
fi

if [[ $TYPE == "bad" || -z $2 ]] ;then
  echo "Usage: $0 [-f] <-i|-s> /path/to/target"
  echo "Adds the cauldron team files to the given chroot"
  echo "Use -i for an iso target, -s for the system tarball"
  exit 1
fi >&2

CHROOTDIR=$2

if ! $FORCE ;then
  if [[ ! -x $CHROOTDIR/bin/bash ]] ;then
    echo "Chroot at $CHROOTDIR failed sanity check (no bash?)"
    exit 2
  fi >&2
fi

MYDIR=$(readlink -f ${0%/*}/..)

if ! [[ -e $MYDIR/base/etc/shadow ]] ;then
  echo "Failed sanity check: Cannot find base/etc/shadow in my dir"
  echo "(assumed to be $MYDIR)"
  exit 2
fi >&2


rm -rf $TEMPDIR
mkdir -m 0700 $TEMPDIR
cp -a $MYDIR/base/* $TEMPDIR/

# ISO Sauce
if [[ $TYPE == "iso" ]] ;then
  cp -a $MYDIR/iso/* $TEMPDIR/
fi

# System Sauce
if [[ $TYPE == "system" ]]
then
  # make sure that grub the grub files are available in /boot
  cp -a $CHROOTDIR/usr/lib/grub/i386-pc/* $TEMPDIR/boot/grub/
fi

# ==== FIXUP starts here ====
chown -R 0:0 $TEMPDIR/
chmod -R u=rwX,go=u-w $TEMPDIR/
chmod 0600 $TEMPDIR/etc/shadow
# ==== end fixup ====

for i in $(find $TEMPDIR -print)
do
  FILE=${i#$TEMPDIR/}
  if [[ -d $i ]]
  then
    continue
  fi

  if [[ -e $CHROOTDIR/$FILE ]]
  then
    echo -n "Overwrite ${FILE}? [yn] "
    read -n1 OVERWRITE
    echo ""
    if [[ $OVERWRITE == y ]]
    then
      cp -a $TEMPDIR/$FILE $CHROOTDIR/
    fi
  else
    cp -a $TEMPDIR/$FILE $CHROOTDIR/
  fi
done

rm -rf $TEMPDIR

