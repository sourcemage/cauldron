#!/bin/bash

COMPRESS=false
ISOCHOWN=false
KEEP=

function usage() {
	cat << EndUsage
Usage: $(basename $0) [-hu] /path/to/target ISO_VERSION

Generates a bootable iso9660 iso file using /path/to/target. The output file is
named ISO_VERSION. Also creates metadata information appropriate to the iso
(publisher, preparer, volume_id, etc.). Uses ISO_VERSION for the volume_id
field. This script requires superuser privileges.

Required:
	/path/to/target
	    The target directory you would like to chroot to. Defaults to
	    current working directory.

	ISO_VERSION
	    A string that specifies the filename of the iso output file.
	    you must specify an absolute path or the command will not likely be
	    found (a way around this would be to either set the path as part of
	    the command to execute, or to set the command to be /bin/bash -l
	    some_command_without_abs_path). Defaults to "/bin/bash -l".
Options:
	-u  Change ownership of output files to $UID:$GID

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":kuzh" Options
do
	case $Options in
		k ) KEEP="-k" ;;
		u ) ISOCHOWN=true ;;
		z ) COMPRESS=true ;;
		h ) usage ;;
		* ) echo "Unrecognized option" >&2 && usage ;;
	esac
done
shift $(($OPTIND - 1))

SELF=$0
SUDOCMD=""

if [[ $UID -ne 0 ]]
then
	if [[ -x $(which sudo) ]]
	then
		SUDOCMD="sudo"
	else
		echo "Please enter the root password."
		exec su -c "$SELF $*" root
	fi
fi
ISO_CHROOT=$1
ISO_VERSION=$2

$SUODOCMD mkisofs -R -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V ${ISO_VERSION} -publisher "Source Mage GNU/Linux" -p "Cauldron" -o "${ISO_VERSION}.iso" "$ISO_CHROOT"

if $COMPRESS || [[ -n $KEEP ]]
then
	$SUODOCMD bzip2 -f -v $KEEP "${ISO_VERSION}.iso"
fi

[[ $ISOCHOWN ]] && $SUDOCMD chown $UID:$GID ${ISO_VERSION}.iso*

