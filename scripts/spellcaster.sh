#!/bin/bash

# this script handles automatically casting all required spells into the ISO
# chroot, and also the casting and subsequent dispelling (with caches enabled)
# of the optional spells.

if [[ -n $CAULDRON_CHROOT && $# -eq 0 ]]
then
	# first cast the required spells (don't dispel, since these are needed
	# for the ISO to function)
	/usr/bin/cast $(tr '\n' ' ' </"$rspells") &&

	# now cast and dispel the optional spells, so that we have the cache
	# files available
	/usr/bin/cast $(tr '\n' ' ' </"$ospells") &&
	/usr/bin/dispel $(tr '\n' ' ' </"$ospells")

	exit $?
fi

MYDIR="$(dirname $0)"
CAULDRONDIR="$MYDIR"/../data

function usage() {
  cat << EndUsage
Usage: $(basename $0) [-h] /path/to/target ARCHITECTURE

Casts the required and optional spells onto the ISO.
This script requires superuser privileges.

Required:
	/path/to/target
	    The location of the chroot directory you would like to have the
	    casting done in.

	ARCHITECTURE
	    The architecture you are building the ISO for. Although the spells
	    will largely be the same, there will be some differences,
	    particularly in the case of bootloaders. Defaults to "x86" if not
	    specified.

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

SELF="$0"

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

[[ $# -lt 1 ]] && usage
TARGET=$1
shift

TYPE="x86"
[[ $# -gt 0 ]] && TYPE="$1"

export rspells="rspells.$TYPE"
export ospells="ospells.$TYPE"

# check to make sure that the chroot has sorcery set to do caches
if [[ -e "$TARGET"/etc/sorcery/local/config ]]
then
	CONFIG_ARCHIVE=$(grep 'ARCHIVE=' "$TARGET"/etc/sorcery/local/config | cut -d = -f 2 | sed 's/"//g')
	if [[ -n $CONFIG_ARCHIVE && $CONFIG_ARCHIVE != "on" ]]
	then
		echo "Error! TARGET sorcery configured to not archive!" >&2
		echo -n "Set the TARGET sorcery to archive? [yn]" >&2
		read -n1 CHOICE

		if [[ $CHOICE == 'y' ]]
		then
			sed -i 's/ARCHIVE=.*/ARCHIVE="on"/' "$TARGET"/etc/sorcery/local/config
		else
			exit 2
		fi
	fi
fi

cp "$CAULDRONDIR/$rspells" "$TARGET"/
cp "$CAULDRONDIR/$ospells" "$TARGET"/
"$MYDIR/cauldronchr.sh" -d "$TARGET" /"$(basename $0)"
rm "$TARGET/$rspells"
rm "$TARGET/$ospells"
rm "$TARGET/$(basename $0)"

unset rspells
unset ospells

exit 0
