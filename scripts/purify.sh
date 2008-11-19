#!/bin/bash

# The intent of this script is to ensure some starting sanity for producing ISO
# builds from the basesystem tarballs. This is necessary because currently
# there are no sanity checks or testing procedures in place during the
# production of the basesystem tarballs, so sometimes things can sneak in.

# The main source of problems is the /etc hierarchy.

CLEANALL=false

function usage() {
	cat <<EndUsage
Usage: $(basename $0) [-ch] /path/to/target

Ensures starting sanity on a chroot directory by sweeping it for files that
shouldn't be there and deleting them. In the future, this may include adding
files as well if the need arises.

Require:
	/path/to/target
	    The path to the target directory you wish to purify.

Options:
	-c  Run cleaniso.sh -a on the target as well.

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":ah" Option
do
	case $Option in
		c ) CLEANALL=true ;;
		h ) usage ;;
		* ) echo "Unrecognized option." >&2 && usage ;;
	esac
done
shift $(($OPTIND - 1))

SELF=$0

if [[ $UID -ne 0 ]]
then
	if [[ -x $(which sudo > /dev/null 2>&1) ]]
	then
		exec sudo "$SELF $*"
	else
		echo "Please enter the root password."
		exec su -c "$SELF $*" root
	fi
fi

# Check to make sure we have the right number of arguments
# taking the option flag into account
[[ $# -eq 1 ]] || usage

# location of ISO chroot to clean from
TARGET="$1"
shift

# Ensure sanity of chroot by making sure that it has
# rm and rmdir.
if ! [[ -e "$TARGET/bin/rm" ]]
then
	echo "Error: /bin/rm not found in $TARGET" >&2
	exit 2
fi
if ! [[ -e "$TARGET/bin/rmdir" ]]
then
	echo "Error: /bin/rmdir not found in $TARGET" >&2
	exit 2
fi

# if called with -c, run cleaniso.sh
$CLEANALL && cleaniso.sh -a "$TARGET"

[[ -e "$TARGET"/etc/udev/rules.d/70-persistent-net.rules ]] && rm "$TARGET"/etc/udev/rules.d/70-persistent-net.rules

