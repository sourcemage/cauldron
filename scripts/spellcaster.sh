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
	while getopts ":i:s:h" Option
	do
		case $Option in
			i ) ISODIR="${OPTARG%/}" ;;
			s ) SYSDIR="${OPTARG%/}" ;;
			h ) usage ;;
			* ) echo "Unrecognized option." >&2 && usage ;;
		esac
	done
	return $(($OPTIND - 1))
}

function priv_check() {
	local SELF="$0"

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
}

function directory_check() {
	if [[ ! -d $1 ]]
	then
		mkdir -p $1
	fi
}

# check to make sure that the chroot has sorcery set to do caches
function sanity_check() {
	local config="$TARGET/etc/sorcery/local/config"
	local arch=
	local choice=

	# Ensure that TARGET is a directory
	[[ -d "$TARGET" ]] || {
		echo "$TARGET does not exist!"
		exit 3
	}

	# If ISODIR is not a directory, create it.
	directory_check "$ISODIR"

	# If ISODIR/var/cache/sorcery is not a directory, create it.
	directory_check "$ISODIR/var/cache/sorcery"

	# If ISODIR/var/spool/sorcery is not a directory, create it.
	directory_check "$ISODIR/var/spool/sorcery"

	# If SYSDIR is not a directory, create it.
	directory_check "$SYSDIR"

	# If SYSDIR/var/cache/sorcery is not a directory, create it.
	directory_check "$SYSDIR/var/cache/sorcery"

	# If SYSDIR/var/spool/sorcery is not a directory, create it.
	directory_check "$SYSDIR/var/spool/sorcery"

	if [[ -e "$config" ]]
	then
		arch="$(source "$config" &> /dev/null && echo $ARCHIVE)"
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
	cat > "$TARGET"/build_spells.sh <<-'SPELLS'

	if [[ -n $CAULDRON_CHROOT && $# -eq 0 ]]
	then

		# If console-tools is found in TARGET, get rid of it to make
		# way for kbd
		[[ $(gaze -q installed console-tools) != "not installed" ]] &&
		dispel --orphan always console-tools

		# push the needed spells into the install queue
		cat rspells ispells ospells > /var/log/sorcery/queue/install

		# cast all the spells using the install queue and save the
		# return value to a log file
		/usr/sbin/cast --queue 2> /build_spells.log
		echo $? >> /build_spells.log

		# make a list of the caches to unpack for system
		for spell in $(</rspells)
		do
			gaze installed $spell &> /dev/null &&
			echo $spell-$(gaze -q installed $spell)
		done > /sys-list || exit 42

		# make a list of the caches to unpack for iso
		for spell in $(</ispells)
		do
			gaze installed $spell &> /dev/null &&
			echo $spell-$(gaze -q installed $spell)
		done > /iso-list || exit 42

		# make a list of the optional caches to unpack for iso
		for spell in $(</ospells)
		do
			gaze installed $spell &> /dev/null &&
			echo $spell-$(gaze -q installed $spell)
		done > /opt-list || exit 42
	fi
SPELLS

	chmod a+x "$TARGET"/build_spells.sh
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
parse_options $*
shift $?

priv_check $*

[[ $# -lt 1 ]] && usage
TARGET="${1%/}"
shift

[[ $# -gt 0 ]] && TYPE="$1"
TYPE="${TYPE:-x86}"

ISODIR="${ISODIR:-/tmp/cauldron/iso}"
SYSDIR="${SYSDIR:-/tmp/cauldron/sys}"

sanity_check

prepare_target

# chroot and build all of the spells inside the TARGET
"$MYDIR/cauldronchr.sh" -d "$TARGET" /build_spells.sh

for cache in $(<"$TARGET"/sys-list)
do
	tar xjf "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 -C "$SYSDIR"/
done

# copy the caches over and unpack their contents
for cache in $(<"$TARGET"/iso-list)
do
	tar xjf "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 -C "$ISODIR"/
	cp "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 "$ISODIR"/var/cache/sorcery/
done

# copy the caches over (only!)
for cache in $(<"$TARGET"/opt-list)
do
	cp "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 "$ISODIR"/var/cache/sorcery/
done

# Keep a clean kitchen, wipes up the leftovers from the preparation step
clean_target

exit 0
