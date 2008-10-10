#!/bin/bash

COMPRESS="no"
KEEP=

while getopts "z" Options
do
	case $Options in
		"z") COMPRESS="yes"
		"k") KEEP="-k"
	esac
done
shift $(($OPTIND - 1))

ISO_CHROOT=$1
ISO_VERSION=$2

mkisofs -R -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V SOURCEMAGE -o "${ISO_VERSION}.iso" "$ISO_CHROOT"

if [[ "$COMPRESS" == yes || -n "$KEEP" ]]
then
	bzip2 -f -v $KEEP "${ISO_VERSION}.iso"
fi

