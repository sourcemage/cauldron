#!/bin/bash
#
# Usage: cauldronchr.sh [-d /path/to/chroot] [CHROOT_CMD]
# assumes $CWD as chroot path and /bin/bash -l as CHROOT_CMD
# if not specified

SELF=$0

[[ $UID -eq 0 ]] || {
	echo "Enter the root password, please."
	exec su -c "$SELF $*" root
}

CHROOT_DIR=
CHROOT_CMD=

# dir to chroot to is either $1 or $CWD
while getopts ":d:" Option
do
	case $Option in
		d ) CHROOT_DIR="$OPTARG" ;;
		* ) ;;
	esac
done
shift $(($OPTIND - 1))

CHROOT_DIR="${CHROOT_DIR:-.}"
[[ $# -gt 0 ]] && CHROOT_CMD="$@"
CHROOT_CMD="${CHROOT_CMD:-/bin/bash -l}"

mount --bind /dev "$CHROOT_DIR"/dev
mount --bind /dev/pts "$CHROOT_DIR"/dev/pts
mount --bind /proc "$CHROOT_DIR"/proc

chroot "$CHROOT_DIR" $CHROOT_CMD

umount "$CHROOT_DIR"/proc
umount "$CHROOT_DIR"/dev/pts
umount "$CHROOT_DIR"/dev
