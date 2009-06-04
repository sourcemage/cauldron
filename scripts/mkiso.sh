#!/bin/bash

COMPRESS=false
ISOCHOWN=false
KEEP=

function usage() {
	cat << EndUsage
Usage: $(basename $0) [-hu] [-i ISO] ISO_VERSION

Generates a bootable iso9660 iso file. The output file is named ISO_VERSION in
the current directory. Also creates metadata information appropriate to the iso
(publisher, preparer, volume_id, etc.). Uses ISO_VERSION for the volume_id
field. This script requires superuser privileges.

Required:
	ISO_VERSION
	    A string that specifies the filename of the iso output file.
	    You must specify an absolute path or the command will not likely be
	    found (a way around this would be to either set the path as part of
	    the command to execute, or to set the command to be /bin/bash -l
	    some_command_without_abs_path). Defaults to "/bin/bash -l".
Options:
	-i  Path to iso build directory (ISO). Defaults to /tmp/cauldron/iso.

	-u  Change ownership of output files to $UID:$GID. You must specify the
	    $UID:$GID pair as a string such as root:root or 0:0 or the script
	    will fail.

	-z  Compress the resulting ISO with bzip2.

	-k  Keep the original ISO file in addition to the compressed version
	    when compressing. Implies -z.

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":i:ku:zh" Options
do
	case $Options in
		i ) ISODIR="$OPTARG" ;;
		k ) KEEP="-k" ;;
		u ) ISOCHOWN=true
			CHOWNSTR="$OPTARG"
			;;
		z ) COMPRESS=true ;;
		h ) usage ;;
		* ) echo "Unrecognized option" >&2 && usage ;;
	esac
done
shift $(($OPTIND - 1))

SELF=$0

if [[ $UID -ne 0 ]]
then
	if [[ -x $(which sudo 2> /dev/null) ]]
	then
		exec sudo -H $SELF $*
	else
		echo "Please enter the root password."
		exec su -c "$SELF $*" root
	fi
fi

ISODIR="${ISODIR:-/tmp/cauldron/iso}"

[[ $# -ne 1 ]] && usage
ISO_VERSION=$1

if MKISOUTIL=$(which mkisofs) || MKISOUTIL=$(which genisoimage)
then
	$MKISOUTIL -R -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V ${ISO_VERSION} -publisher "Source Mage GNU/Linux" -p "Cauldron" -o "${ISO_VERSION}.iso" "$ISODIR"
else
	echo "$(basename $0) needs either mkisofs or genisoimage."
	exit 1;
fi

if $COMPRESS || [[ -n $KEEP ]]
then
	bzip2 -f -v $KEEP "${ISO_VERSION}.iso"
fi

[[ $ISOCHOWN ]] &&  chown "$CHOWNSTR" "${ISO_VERSION}".iso*

