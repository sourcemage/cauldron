#!/bin/bash
[[ -e $1/proc/cpuinfo ]] ||
  mount -t proc proc $1/proc

mount | grep -q $1/var/spool/sorcery ||
  mount --bind /var/spool/sorcery $1/var/spool/sorcery

[[ -e $1/dev/console ]] ||
  mount --bind /dev $1/dev
