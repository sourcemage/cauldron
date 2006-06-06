#!/bin/sh

PROGRAM=/bin/false
RUNLEVEL=DEV
ESSENTIAL=yes

. /etc/init.d/smgl_init
. /etc/sysconfig/init

start()
{
  { >/etc/writable ; } 2>/dev/null && return 0
  # If it's already writable, do nothing.

  required_executable /bin/mount
  required_executable /bin/mkdir
  required_executable /bin/cp

  echo "Mounting tmpfs..."
  /bin/mount -t tmpfs tmpfs /tmp
  evaluate_retval

  for i in etc root var/log var/lib/nfs ;do
    echo "setting up a writeable /$i..."
    /bin/mkdir -p /tmp/$i &&
    /bin/cp -a --parents /$i /tmp &&
    /bin/mount --bind /tmp/$i /$i
    evaluate_retval
  done

  /bin/mount proc -t proc /proc
}

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
