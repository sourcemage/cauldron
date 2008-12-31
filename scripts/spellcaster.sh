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

	# Copy any spell-specific required options into the TARGET
	[[ -d "$TARGET"/etc/sorcery/local/depends/ ]] ||
		mkdir -p "$TARGET"/etc/sorcery/local/depends/
	cp "$CAULDRONDIR"/depends/* "$TARGET"/etc/sorcery/local/depends/

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

function install_kernel() {
	local SRC=$1
	local DST=$2
	local kconfig=$3
	local version=
	local kernel=

	# Try to autodetect the location of the kernel config based on whether
	# the linux spell was used or not.
	if [[ -z $kconfig ]]
	then
	fi

	if gaze -q installed linux &> /dev/null
	then
		version=$(gaze -q installed linux)
		kernel=/boot/vmlinuz

	# Try to autodetect the linux kernel version using spell version or
	# kernel config
	if [[ -z $version ]]
	then
		version="$(zgrep 'Linux kernel version:')"
		version="${version#*version: }"
	fi

	# Try to guess the location of the kernel itself
	kernel=

	cp "$kconfig" "$DST"/boot/config-$version
	cp "$SRC"/ "$DST"/
	cp "$SRC"/ "$DST"/
	cp "$SRC"/ "$DST"/
	cp "$SRC"/ "$DST"/
	cp "$SRC"/ "$DST"/
}

function setup_sys() {
	local SPOOL="$TARGET/var/spool"
	local SORCERY="sorcery-stable.tar.bz2"
	local SORCERYDIR="$TARGET/usr/src/sorcery"
	local gvers=$(head -n1 "$TARGET"/var/lib/sorcery/codex/stable/VERSION)
	local stable="stable-${gvers%-*}.tar.bz2"
	local syscodex="$SYSDIR/var/lib/sorcery/codex"
	local tablet="$SYSDIR/var/state/sorcery/tablet"
	local packages="$SYSDIR/var/state/sorcery/packages"
	local depends="$SYSDIR/var/state/sorcery/depends"

	# unpack the sys caches into SYSDIR
	for cache in $(<"$TARGET"/sys-list)
	do
		tar xjf "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 -C "$SYSDIR"/
	done

	# download sorcery source
	(
		cd "$SPOOL"
		wget http://download.sourcemage.org/sorcery/$SORCERY
	)

	# unpack and install sorcery into SYSDIR
	tar jxf "$SPOOL"/$SORCERY -C "$TARGET/usr/src"
	pushd "$SORCERYDIR" &> /dev/null
	./install "$SYSDIR"
	popd

	# install the stable grimoire used for build into SYSDIR
	(
		cd "$TARGET/tmp"
		wget http://download.sourcemage.org/codex/$stable
	)
	[[ -d "$syscodex" ]] || mkdir -p $syscodex &&
	tar jxf $stable -C "$syscodex"/
	mv "$syscodex"/${stable%.tar.bz2} "$syscodex"/stable

	# generate the depends and packages info for sorcery to use
	. "$SYSDIR"/etc/sorcery/config
	for spell in "$tablet"/*
	do
		for date in "$spell"/*
		do
			tablet_get_version $date ver
			tablet_get_status $date stat
			tablet_get_depends $date dep
			echo "${spell##*/}:${date##*/}:$stat:$ver" >> "$packages"
			cat "$dep" >> "$depends"
		done
	done
}

function setup_iso() {
	# copy the iso caches over and unpack their contents
	for cache in $(<"$TARGET"/iso-list)
	do
		tar xjf "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 -C "$ISODIR"/
		cp "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 "$ISODIR"/var/cache/sorcery/
	done

	# copy (only!) the optional caches over
	for cache in $(<"$TARGET"/opt-list)
	do
		cp "$TARGET"/var/cache/sorcery/$cache*.tar.bz2 "$ISODIR"/var/cache/sorcery/
	done
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
		"$TARGET/build_spell.sh"
}

# main()
priv_check $*

parse_options $*
shift $?

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

# unpack sys caches and set up sorcery into SYSDIR
setup_sys

# unpack iso caches and copy iso and optional caches into ISODIR
setup_iso

# Keep a clean kitchen, wipes up the leftovers from the preparation step
clean_target

exit 0
