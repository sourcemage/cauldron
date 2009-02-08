#!/bin/bash
#
#

MYDIR="$(dirname $0)"
CAULDRONDIR="$MYDIR/../data"
TMPDIR="/tmp/cauldron"

function usage() {
	cat << EndUsage
Usage: $(basename $0) [-h] [-o OUTPUT] [-t TYPE] /path/to/target
Performs Quality Assurance on the target chroot directory. The target must be a
full chroot.

Options:
	/path/to/target
	    The target directory you would like to perform Quality Assurance
	    on. Defaults to current working directory.

	-h  Shows this help information

	-o  File to write the output to. Defaults to /tmp/cauldron/MISSING_INITS.

	-t  Set the target architecture type to TYPE (currently only x86
	    supported).
EndUsage
	exit 1
} >&2

# dir to chroot to is either $1 or $CWD
while getopts ":o:t:h" Option
do
	case $Option in
		o ) OUTPUT="$OPTARG" ;;
		t ) TYPE="$OPTARG" ;;
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

[[ $# -eq 1 ]] && TARGET="${1%/}"
TARGET="${TARGET:-.}"
TYPE="${TYPE:-x86}"

INSTALL_LOGS="$TARGET/var/log/sorcery/install"
CODEX="$TARGET/var/lib/sorcery/codex"
PACKAGES="$TARGET/var/state/sorcery/packages"

rspells="$CAULDRONDIR/rspells.$TYPE"
ispells="$CAULDRONDIR/ispells.$TYPE"
ospells="$CAULDRONDIR/ospells.$TYPE"

if [[ -z $OUTPUT ]]
then
	OUTPUT="$TMPDIR/MISSING_INITS"
	[[ -d "$TMPDIR" ]] || mkdir -p "$TMPDIR"
fi

# ensure that the output file starts as empty
rm -f "$OUTPUT"

echo "Checking spells for missing init.d files..."
for list in "$rspells" "$ispells" "$ospells"
do
	for spell in $(<$list)
	do
		echo ".. checking $spell"
		if ls "$CODEX"/stable/*/$spell/init.d &> /dev/null
		then
			log="$spell-$(grep ${spell}: "$PACKAGES" | cut -d: -f4)"
			for init in $(find "$CODEX"/stable/*/$spell/init.d -type f)
			do
				if [[ -x $init ]]
				then
					if ls "$INSTALL_LOGS"/$spell* &> /dev/null
					then
						if ! grep -q "^/etc/init.d/.*/${init##*/}" "$INSTALL_LOGS"/$log
						then
							echo "--> $spell is missing init.d files!"
							echo "$spell" >> "$OUTPUT"
							break
						fi
					fi
				fi
			done
		fi
	done
done

if [[ -s "$OUTPUT" ]]
then
	sort -u -o "$OUTPUT" "$OUTPUT"
	echo "Spells with missing init.d files:"
	cat "$OUTPUT" | column
	echo -n "Re-cast these spells? [yn] "
	read -n1 RECAST
	echo ""
	if [[ $RECAST == 'y' ]]
	then
		echo "Re-casting spells with missing init.d files..."
		for spell in $(<$OUTPUT)
		do
			"$MYDIR"/cauldronchr.sh -d "$TARGET" cast -c $spell
		done
	fi
fi

