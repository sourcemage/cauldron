#/bin/bash

function usage() {
	cat <<EndUsage
Usage: $(basename $0) iso_chroot

Cleans unwanted files and directories from iso_chroot. This script requires
superuser privileges.

Options:
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

# Check to make sure we have the right number of arguments
# taking the option flag into account
if [[ $# -ne 1 ]]
then
	usage
fi

# location of ISO chroot to clean from
ISOCHROOT="$1"
shift

# Ensure sanity of chroot by making sure that it has
# rm and rmdir.
if ! [[ -e "$ISOCHROOT/bin/rm" ]]
then
	echo "Error: /bin/rm not found in $ISOCHROOT" >&2
	exit 2
fi

echo "Removing $ISOCHROOT/boot/grub"
chroot "$ISOCHROOT" /bin/rm -fr /boot/grub

echo "Removing $ISOCHROOT/usr/include"
chroot "$ISOCHROOT" /bin/rm -fr /usr/include

echo "Removing $ISOCHROOT/usr/share/doc"
chroot $ISOCHROOT /bin/rm -fr /usr/share/doc

echo "Removing $ISOCHROOT/var/log/sorcery"
chroot $ISOCHROOT /bin/rm -fr /var/log/sorcery

echo "Removing $ISOCHROOT/var/state/sorcery"
chroot $ISOCHROOT /bin/rm -fr /var/state/sorcery
