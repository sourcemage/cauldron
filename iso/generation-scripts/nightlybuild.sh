#!/bin/bash
LOGFILE="$(pwd)/isogen-log.$(date +%Y%m%d%H)"
[[ -e mkprep ]] ||
  cd ${0%/*}

if ! [[ $1 ]] ;then
  echo "syntax: $0 /path/to/chroot"
  exit 1
fi

if ! [[ -x $1/usr/sbin/sorcery ]] ;then
  echo "error: $1 must be a working chroot"
  exit 1
fi

exec 17>$LOGFILE
export ISOGEN_LOGFILE=/dev/fd/17

./sanitize_chroot.sh $1

export ISO_VERSION="smgl-nightly"
. /etc/smgl-isogen.conf
. config

rm -f $1/root/sorcery-$SVERSION.tar.bz2
rm -f $1/root/$GVERSION.tar.bz2
./mkprep $1/root/p4 1>&17 2>&17

chroot $1 /root/p4/generation-scripts/autoupdate.sh
