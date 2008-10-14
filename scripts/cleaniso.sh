#/bin/bash

# CLEANFILEs are located in cauldron/data/cleaners

CLEANALL=false
CLEANERS="$(dirname $0)/../data/cleaners"

function usage() {
	cat <<EndUsage
Usage: $(basename $0) [-a] iso_chroot cleaner(s)

For each cleaner specified as an argument, cleans the files and
directories listed therein from iso_chroot.  A cleaner is the ouput of
'gaze install \$SPELL' minus whatever you don't want removed. This
script requires superuser privileges.

Options:
	-a  Run on all cleaner files in the cauldron cleaner
	    directory. If this option is specified, any arguments
	    provided beyond iso_chroot are ignored.

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":ah" Option
do
	case $Option in
		a ) CLEANALL=true ;;
		h ) usage ;;
		* ) echo "Unrecognized option." >&2 && usage ;;
	esac
done
shift $(($OPTIND - 1))

SELF=$0

if [[ $UID -ne 0 ]]
then
	if [[ -x $(which sudo > /dev/null) ]]
	then
		exec sudo "$SELF $*"
	else
		echo "Please enter the root password."
		exec su -c "$SELF $*" root
	fi
fi

# Check to make sure we have the right number of arguments
# taking the option flag into account
if [[ $# -eq 1 ]]
then
	if ! $CLEANALL
	then
		usage
	fi
elif [[ $# -lt 2 ]]
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
if ! [[ -e "$ISOCHROOT/bin/rmdir" ]]
then
	echo "Error: /bin/rmdir not found in $ISOCHROOT" >&2
	exit 2
fi

if $CLEANALL
then
	LIST=( $(ls $CLEANERS/*) )
else
	LIST=( $@ )
fi

for CLEANER in "${LIST[@]}"
do
	# Reverse sort ensures that the gaze install output we have lists files
	# before directories, so that directories can be cleaned using rmdir
	# after the files are cleaned first. This is safer, since it avoids the
	# mighty 'rm -fr' oopses.
	for DIRT in $(sort -r "$CLEANER")
	do
		if [[ -e $ISOCHROOT/$DIRT ]]
		then
			# test if current listing is a dir, should only be true after
			# the files under the dir are already cleaned
			if [[ -d "$DIRT" ]]
			then
				# chroot and clean a directory using rmdir
				echo "Attempting to remove directory $ISOCHROOT/$DIRT"
				 chroot "$ISOCHROOT" rmdir --ignore-fail-on-non-empty "$DIRT"
			else
				# chroot and clean an individual file
				echo "Attempting to delete $ISOCHROOT/$DIRT"
				 chroot "$ISOCHROOT" rm "$DIRT"
			fi
		fi
	done
done

