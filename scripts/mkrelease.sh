#!/bin/bash

TARGET=$1
VERSION=$2

function usage() {
	cat << EndUsage
Usage: $(basename $0) [-h] /path/to/target VERSION

Creates an official release ISO from /path/to/target for the ISO
version specified as VERSION. This script requires superuser
privileges.

Required:
	/path/to/target
	    The target directory you would like to make a releasable
	    ISO from.

	VERSION
	    A string which describes the version of the ISO to
	    release. Since this script is for making official
	    releases, the string will be prepended with smgl-,
	    resulting in smgl-VERSION.iso for the final ISO output.

Options:
	-u  chown output files to $UID:$GID

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":h" Option
do
	case $Option in
		h ) usage ;;
		* ) echo "Unrecognized option." >&2 && usage ;;
	esac
done
shift $(($OPTIND - 1))

[[ $# -lt 2 ]] && usage

GRIMOIRE_VER=$(< "$TARGET"/var/lib/sorcery/codex/stable/VERSION)

for file in $(grep -qr '@ISO_VERSION@' $TARGET/{etc,isolinux,usr/share/doc/smgl.install}/*)
do
	sed -i "s/@ISO_VERSION@/$VERSION/" "$file"
done

sed -i "s/@GRIMOIRE_VERSION@/$GRIMOIRE_VER/" "$TARGET"/isolinux/isolinux.msg

$(dirname $0)/mkiso.sh -k "$TARGET" "smgl-$VERSION"

