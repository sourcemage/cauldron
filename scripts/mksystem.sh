#!/bin/bash

function usage() {
	cat << EndUsage
Usage: $(basename $0) -d /path/to/target /path/to/output
Generates a compressed tarball of the "system" directory specified in
/path/to/target. This script requires superuser privileges.

Required:
	/path/to/target
	    The path to the "system" directory.

	/path/to/output
	    The path to the desired output file.

Options:
	-v  if specified, tar progress is output to STDOUT

	-h  Shows this help information
EndUsage
	exit 1
} >&2

while getopts ":v" Option
do
	case $Option in
		v ) VERBOSE="-v" ;;
		h ) usage ;;
		* ) echo "Unrecognized option." >&2 && usage ;;
	esac
done
shift $(($OPTIND - 1))

SELF=$0
SUDOCMD=""

if [[ $UID -ne 0 ]]
then
	if [[ -x $(which sudo) ]]
	then
		SUDOCMD="sudo"
	else
		echo "Please enter the root password."
		exec su -c "$SELF $*" root
	fi
fi

SYSDIR=${1:-system}
SYSTAR="${2:-$(basename $SYSDIR).tar.bz2}"

[[ $(dirname $SYSDIR) == '.' ]] && SYSDIR="$PWD/$SYSDIR"
[[ $(dirname $SYSTAR) == '.' ]] && SYSTAR="$PWD/$SYSTAR"


[[ -z $SYSDIR ]] && usage

cd $SYSDIR
$SUDOCMD tar $VERBOSE -jcf "$SYSTAR" *
echo "Output written to: $SYSTAR"

exit
