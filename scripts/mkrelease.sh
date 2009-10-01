#!/bin/bash

MYDIR="$(dirname $0)"

ISOCHOWN=""

function usage() {
	cat << EndUsage
Usage: $(basename $0) [-h] [-i ISO] VERSION

Creates an official release ISO for the ISO version specified as VERSION. This
script requires superuser privileges.

Required:
	VERSION
	    A string which describes the version of the ISO to
	    release. Since this script is for making official
	    releases, the string will be prepended with smgl-,
	    resulting in smgl-VERSION.iso for the final ISO output.

Options:
	-i  Path to iso build directory (ISO). Defaults to /tmp/cauldron/iso.

	-u  Change ownership of output files to $UID:$GID. You must specify the
	    $UID:$GID pair as a string such as root:root or 0:0 or the script
	    will fail.

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":i:u:h" Option
do
	case $Option in
		i ) TARGET="$OPTARG" ;;
		u ) ISOCHOWN="-u"
			CHOWNSTR="$OPTARG"
			;;
		h ) usage ;;
		* ) echo "Unrecognized option." >&2 && usage ;;
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

TARGET="${TARGET:-/tmp/cauldron/iso}"

[[ $# -ne 1 ]] && usage
VERSION=$1

# Get the grimoire version used to generate all the spells in the ISO.
GRIMOIRE_VER=$(head -n1 "$TARGET"/etc/grimoire_version)

# Replace all ISO_VERSION placeholders with the ISO version passed on the
# commandline.
for file in $(grep -lr '@ISO_VERSION@' $TARGET/{etc,isolinux,usr/share/doc/smgl.install}/*)
do
	 sed -i "s/@ISO_VERSION@/$VERSION/" "$file"
done

# Replace the GRIMOIRE_VERSION placeholder (currently only in isolinux.msg).
sed -i "s/@GRIMOIRE_VERSION@/$GRIMOIRE_VER/" "$TARGET"/isolinux/isolinux.msg

# Replace the ISO_YEAR placeholder with the current year in which the ISO is generated
# This makes keeping the copyright up-to-date trivial for the person building the ISO
sed -i "s/@ISO_YEAR@/$(date +%Y)/" "$TARGET"/isolinux/isolinux.msg

# Generate the release ISO. Currently we force KEEP and COMPRESSION.
if [[ -n $ISOCHOWN ]]
then
	"$MYDIR"/mkiso.sh "$ISOCHOWN $CHOWNSTR" -kz "$TARGET" "smgl-$VERSION"
else
	"$MYDIR"/mkiso.sh -kz -i "$TARGET" "smgl-$VERSION"
fi

