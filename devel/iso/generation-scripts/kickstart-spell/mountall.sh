#!/bin/sh
# vim:set ts=2 sw=2 et:

PROGRAM=/bin/false
RUNLEVEL=S
PROVIDES=local_fs
ESSENTIAL=yes

. /etc/init.d/smgl_init
. /etc/sysconfig/init

checkfs()
{
  [ -e /fastboot     ]  &&  return
  [ -e /forcefsck    ]  &&  FORCE="-f"
  [ "$FSCKFIX" = yes ]  &&  FIX="-y"  ||  FIX="-a"

  echo "Checking file systems..."
  /sbin/fsck -T -C -A $FIX $FORCE
  evaluate_retval

  if [ $? -gt 1 ];  then
    $WARNING
    echo  "fsck failed."
    echo  "Please repair your file system"
    echo  "manually by running /sbin/fsck"
    echo  "without the -a option"
    $NORMAL
    /sbin/sulogin
    /sbin/reboot  -f
  fi

  rm -f /fastboot /forcefsck
}

start()
{
  required_executable /bin/mount
  required_executable /sbin/fsck

#  echo "Mounting root file system read only..."
#  mount   -n  -o  remount,ro  /
#  evaluate_retval || exit 1

  checkfs

#  echo "Mounting root file system read/write..."
#  {
#    mount    -n -o remount,rw / &&
#    echo     > /etc/mtab        &&
#    mount    -f -o remount,rw /
#  } || exit 1

  if optional_executable /sbin/swapon ; then
    echo -n "Activating swap... "
    swapon -a 2> /dev/null
    evaluate_retval
  fi

  echo "Mounting local filesystems..."
# Fixed so as to not mount networked filesystems yet (no networking)
# mountnfs.sh will take care of this.
  mount    -a  -t  nosmbfs,nonfs,noncpfs
  evaluate_retval

  echo "Creating /var/run/utmp..."
  [ -d /var/run ] && touch /var/run/utmp
  evaluate_retval
  echo "Writing dmesg log to /var/log/dmesg..."
  [ -d /var/log ] && dmesg  >  /var/log/dmesg
  evaluate_retval
  echo "Making /tmp/.ICE-unix temporary directory..."
  [ -d /tmp     ] && mkdir -p /tmp/.ICE-unix && chmod 1777 /tmp/.ICE-unix
  evaluate_retval

  exit 0
}


# Simpleinit handles umounting and stuff.
stop()
{
  exit 0
}

restart()       { exit 3; }
reload()        { exit 3; }
force_reload()  { exit 3; }
status()        { exit 3; }

usage()
{
  echo "Usage: $0 {start|stop}"
  echo "Warning: Do not run this script manually!"
}
