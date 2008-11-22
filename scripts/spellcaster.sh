#!/bin/bash

# this script handles automatically casting all required spells into the ISO
# chroot, and also the casting and subsequent dispelling (with caches enabled)
# of the optional spells.

if [[ -n $CAULDRON_CHROOT && $# -eq 0 ]]
then
	if [[ $CAULDRON_CAST = y ]]
	then
		# cast all spells
		/usr/bin/cast $(tr '\n' ' ' </"$rspells") &&
		/usr/bin/cast $(tr '\n' ' ' </"$ospells")

	elif [[ $CAULDRON_DISPEL = y ]]
	then
		# dispel the optional spells, so that we have only their cache files
		# available
		/usr/bin/dispel $(tr '\n' ' ' </"$ospells")
	fi

	exit $?
fi

MYDIR="$(dirname $0)"
CAULDRONDIR="$MYDIR"/../data

function usage() {
  cat << EndUsage
Usage: $(basename $0) [-h] -c | -d /path/to/target ARCHITECTURE

Casts the required and optional spells onto the ISO.
This script requires superuser privileges.

Required:
	-c
	    Cast the required and optional spells in the target directory. This
	    is the default action.

	-d
	    Dispel the optional spells only from the target directory.

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

export CAULDRON_CAST=y

while getopts ":cdh" Option
do
  case $Option in
    c ) export CAULDRON_DISPEL=n ; export CAULDRON_CAST=y ;;
    d ) export CAULDRON_CAST=n ; export CAULDRON_DISPEL=y ;;
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
TARGET="$1"
shift

[[ $# -gt 0 ]] && TYPE="$1"
TYPE="${TYPE:-x86}"

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

# Copy necessary files to the target and chroot
$(grep -q linux "$CAULDRONDIR/{$rspells,$ospells}") && cp "$CAULDRONDIR/config.$TYPE" "$TARGET/etc/sorcery/local/kernel.config"
[[ CAULDRON_CAST = y ]] && cp "$CAULDRONDIR/$rspells" "$TARGET"/
cp "$CAULDRONDIR/$ospells" "$TARGET"/
"$MYDIR/cauldronchr.sh" -d "$TARGET" /"$(basename $0)"

# Clean up the target
[[ CAULDRON_CAST = y ]] && rm "$TARGET/$rspells"
rm "$TARGET/$ospells"
[[ -e "$TARGET/etc/sorcery/local/kernel.config" ]] && rm "$TARGET/etc/sorcery/local/kernel.config"
rm "$TARGET/$(basename $0)"

unset rspells
unset ospells
unset CAULDRON_CAST
unset CAULDRON_DISPEL

exit 0
