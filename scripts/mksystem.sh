#!/bin/bash

function usage() {
	cat << EndUsage
Usage: $(basename $0) [-hv] [-i ISO] [-s SYS]
Generates a compressed tarball of the "system" directory specified in
/path/to/target. This script requires superuser privileges.

Options:
	-i  Path to iso build directory (ISO). Defaults to /tmp/cauldron/iso.

	-s  Path to system build directory (SYS). Defaults to
	    /tmp/cauldron/system.

	-v  if specified, tar progress is output to STDOUT

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":i:s:vh" Option
do
	case $Option in
		i ) ISODIR="$OPTARG" ;;
		s ) SYSDIR="$OPTARG" ;;
		v ) VERBOSE="-v" ;;
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

SYSDIR="${SYSDIR:-/tmp/cauldron/sys}"
ISODIR="${ISODIR:-/tmp/cauldron/iso}"

[[ -z $SYSDIR || ! -d $SYSDIR ]] && usage
[[ -z $ISODIR || ! -d $ISODIR ]] && usage

SYSTAR="$ISODIR/system.tar.bz2"

[[ $(dirname $SYSDIR) != /* ]] && SYSDIR="$PWD/$SYSDIR"
[[ $(dirname $SYSTAR) != /* ]] && SYSTAR="$PWD/$SYSTAR"

echo "Entering $SYSDIR"
cd $SYSDIR &&

echo "Creating $SYSTAR, please be patient"
tar $VERBOSE -jcf "$SYSTAR" *
echo "Output written to: $SYSTAR"

exit
