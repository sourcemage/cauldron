#!/bin/bash

while getopts ":v" Option
do
	case $Option in
		v ) VERBOSE="-v" ;;
		* ) ;;
	esac
done
shift $(($OPTIND - 1))

SYSDIR=${1:-system}
SYSTAR="${2:-$(basename $SYSDIR).tar.bz2}"

[[ $(dirname $SYSDIR) == '.' ]] && SYSDIR="$PWD/$SYSDIR"
[[ $(dirname $SYSTAR) == '.' ]] && SYSTAR="$PWD/$SYSTAR"

function usage() {
	echo ""
	echo "usage: mksystem /path/to/system/dir OUTPUT_FILE"
	echo "where OUTPUT_FILE is specified via an absolute path"
	exit 1
}

[[ -z $SYSDIR ]] && usage

cd $SYSDIR
tar $VERBOSE -jcf "$SYSTAR" *
echo "Output written to: $SYSTAR"

exit
