#!/bin/bash

# this script handles automatically casting all required spells into the ISO
# chroot, and also the casting and subsequent dispelling (with caches enabled)
# of the optional spells.

MYDIR="$(dirname $0)"
CAULDRONDIR="$MYDIR"/../data

function usage() {
  cat << EndUsage
Usage: $(basename $0) [-h] [-i ISO] [-s SYS] /path/to/target ARCHITECTURE

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

	-i  Path to iso build directory (ISO). Defaults to /tmp/cauldron/iso.

	-s  Path to system build directory (SYS). Defaults to
	    /tmp/cauldron/system.
EndUsage
  exit 1
} >&2

function parse_options() {
	while getopts ":cdh" Option
	do
		case $Option in
			i ) ISODIR="${OPTARG%/}" ;;
			s ) SYSDIR="${OPTARG%/}" ;;
			h ) usage ;;
			* ) echo "Unrecognized option." >&2 && usage ;;
		esac
	done
	shift $(($OPTIND - 1))
}

function priv_check() {
	local SELF="$0"

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
}

# check to make sure that the chroot has sorcery set to do caches
function sanity_check() {
	local config="$TARGET/etc/sorcery/local/config"
	local arch=
	local choice=

	# Ensure that TARGET is a directory
	[[ -d "$TARGET" ]] ||
		echo "$TARGET does not exist!" && exit 3

	# If ISODIR is not a directory, create it.
	[[ ! -d "$ISODIR" ]] && mkdir -p "$ISODIR" ||
		echo "couldn't create $ISODIR" && exit 3

	# If SYSDIR is not a directory, create it.
	[[ ! -d "$SYSDIR" ]] && mkdir -p "$SYSDIR" ||
		echo "couldn't create $SYSDIR" exit 3

	if [[ -e "$config" ]]
	then
		arch="$(source "$config" && echo $ARCHIVE)"
		if [[ -n $arch && $arch != "on" ]]
		then
			echo "Error! TARGET sorcery does not archive!" >&2
			echo -n "Set TARGET sorcery to archive? [yn]" >&2
			read -n1 choice
			echo ""

			if [[ $choice == 'y' ]]
			then
				. "$TARGET/var/lib/sorcery/modules/libstate"
				modify_config $config ARCHIVE on
			else
				exit 2
			fi
		fi
	fi
}

function prepare_target() {
	export rspells="rspells.$TYPE"
	export ispells="ispells.$TYPE"
	export ospells="ospells.$TYPE"

	# Copy resolv.conf so spell sources can be downloaded inside the TARGET
	cp -f "$TARGET"/etc/resolv.conf "$TARGET"/tmp/resolv.conf &&
		cp -f /etc/resolv.conf "$TARGET"/etc/resolv.conf

	# If using the linux spell copy the kernel config to TARGET sorcery
	grep -q '^linux$' "$CAULDRONDIR/$rspells" "$CAULDRONDIR/$ospells" &&
	cp "$CAULDRONDIR/config-2.6" "$TARGET/etc/sorcery/local/kernel.config"

	# Copy the list of spells needed for casting into the TARGET if casting
	cp "$CAULDRONDIR/rspells.$TYPE" "$TARGET"/rspells
	cp "$CAULDRONDIR/ispells.$TYPE" "$TARGET"/ispells
	cp "$CAULDRONDIR/ospells.$TYPE" "$TARGET"/ospells

	# generate basesystem casting script inside of TARGET
	cat > "$TARGET"/build_base.sh <<-'BASE'

	# If console-tools is found in TARGET, get rid of it to make way for kbd
	[[ $(gaze -q installed console-tools) != "not installed" ]] &&
		dispel --orphan always console-tools

	if [[ -n $CAULDRON_CHROOT && $# -eq 0 ]]
	then
		# cast basic/required spells
		/usr/sbin/cast $(tr '\n' ' ' </rspells) || exit $?

		# make a list of the caches to unpack for system
		for spell in $(</rspells)
		do
			echo $spell-$(gaze -q installed $spell) >> /sys-list
		done || exit 42
	fi
BASE

	# generate iso spell casting script inside of TARGET
	cat > "$TARGET"/build_iso.sh <<-'ISO'

	if [[ -n $CAULDRON_CHROOT && $# -eq 0 ]]
	then
		# cast optional spells
		/usr/sbin/cast $(tr '\n' ' ' </ispells) || exit $?

		# make a list of the caches to unpack for iso
		for spell in $(</ispells)
		do
			echo $spell-$(gaze -q installed $spell) >> /iso-list
		done || exit 42
	fi
ISO

	# generate optional spell casting script inside of TARGET
	cat > "$TARGET"/build_optional.sh <<-'OPTIONAL'

	if [[ -n $CAULDRON_CHROOT && $# -eq 0 ]]
	then
		# cast optional spells
		/usr/sbin/cast $(tr '\n' ' ' </ospells) || exit $?

		# make a list of the caches to unpack for iso
		for spell in $(</ospells)
		do
			echo $spell-$(gaze -q installed $spell) >> /opt-list
		done || exit 42

		# dispel the optional spells, so that we have only their cache files
		# available
		/usr/sbin/dispel $(tr '\n' ' ' </ospells) || exit $?
	fi
OPTIONAL

	chmod a+x "$TARGET"/build_base.sh
	chmod a+x "$TARGET"/build_iso.sh
	chmod a+x "$TARGET"/build_optional.sh
}

function clean_target() {
	local config="$TARGET/etc/sorcery/local/kernel.config"

	# Restore resolv.conf, the first rm is needed in case something
	# installs a hardlink (like ppp)
	rm -f "$TARGET/etc/resolv.conf" &&
	cp -f "$TARGET/tmp/resolv.conf" "$TARGET/etc/resolv.conf" &&
		rm -f "$TARGET/tmp/resolv.conf"

	# Clean up the target
	rm -f "$TARGET/rspells" \
		"$TARGET/ispells" \
		"$TARGET/ospells" \
		"$TARGET/$config" \
		"$TARGET/build_base.sh" \
		"$TARGET/build_iso.sh" \
		"$TARGET/build_optional.sh"
}

# main()
parse_options

priv_check

[[ $# -lt 1 ]] && usage
TARGET="${1%/}"
shift

[[ $# -gt 0 ]] && TYPE="$1"
TYPE="${TYPE:-x86}"

ISODIR="${ISODIR:-/tmp/cauldron/iso}"
SYSDIR="${SYSDIR:-/tmp/cauldron/sys}"

sanity_check

prepare_target

# chroot and build the basesystem inside the TARGET
"$MYDIR/cauldronchr.sh" -d "$TARGET" /build_base.sh

for cache in $(<"$TARGET"/sys-list)
do
	tar xjf "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 -C "$SYSDIR"/
done

# chroot and build the iso inside the TARGET
"$MYDIR/cauldronchr.sh" -d "$TARGET" /build_iso.sh

# copy the caches over and unpack their contents
for cache in $(<"$TARGET"/iso-list)
do
	tar xjf "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 -C "$ISODIR"/
	cp "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 "$ISODIR"/var/cache/sorcery/
done

# chroot and build the optional spells inside the TARGET
"$MYDIR/cauldronchr.sh" -d "$TARGET" /build_optional.sh

# copy the caches over (only!)
for cache in $(<"$TARGET"/opt-list)
do
	cp "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 "$ISODIR"/var/cache/sorcery/
done

# Keep a clean kitchen, wipes up the leftovers from the preparation step
clean_target

exit 0
