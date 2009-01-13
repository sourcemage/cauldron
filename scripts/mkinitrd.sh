#!/bin/bash
# This script will crank out an initrd image for the ISO to use.

function usage() {
	cat << EndUsage
Usage: $(basename $0) [-o OUTPUT_FILE] [-i ISO] [ISO_KERNEL_VERSION]

Generates an initrd using /path/to/target. The output file is named initrd.gz
and is placed in the current working directory by default, but can be
overridden by the -o option. This script requires superuser privileges.

Required:
	ISO_KERNEL_VERSION
	    A string that specifies the version of the kernel to use. Typically
	    you will only have one kernel version in your iso build directory,
	    but there's nothing which prevents you from having more than one,
	    so you need to specify the version the initrd will be built
	    against.
Options:
	-i  Path to iso build directory (ISO). Defaults to /tmp/cauldron/iso.

	-o FILENAME
	    Specify the output file as FILENAME (can include a path prefix).
	    Defaults to ISO/boot/initrd.gz.

	-h  Shows this help information.
EndUsage
	exit 1
} >&2

while getopts ":i:o:h" Options
do
	case $Options in
		i ) ISODIR="$OPTARG" ;;
		o ) OUTPUT="$OPTARG" ;;
		h ) usage ;;
		* ) echo "Unrecognized option" >&2 && usage ;;
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

ISODIR="${ISODIR:-/tmp/cauldron/iso}"

# ensure full pathnames
if [[ $(dirname "$ISODIR") != /* ]]
then
	ISODIR="$(pwd)/$ISODIR"
fi

# make sure that ISODIR is a directory
if [[ -d $ISODIR ]]
then
  echo "Chroot dir: $ISODIR"
else
  echo "error: $ISODIR is not a directory"
  exit 2
fi

OUTPUT="${OUTPUT:-$ISODIR/boot/initrd.gz}"

KERNEL_VERSION="$1"
# try to get the kernel version if not specified
if [[ -z $KERNEL_VERSION ]]
then
  modules="$ISODIR/lib/modules"
  if [[ $(find $modules -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ]]
  then
    KERNEL_VERSION="$(find $modules -mindepth 1 -maxdepth 1 -type d)"
    KERNEL_VERSION="${KERNEL_VERSION##*/}"
  else
    echo "Kernel version could not be determined, bailing out!"
    exit 3
  fi
fi

if ! [[ -d "$ISODIR"/lib/modules/$KERNEL_VERSION/kernel ]] ;then
  echo "Chroot failed sanity check:"
  echo "Unable to find $ISODIR/lib/modules/$KERNEL_VERSION/kernel"
  exit 2
fi >&2

if ! [[ -f "$ISODIR"/isolinux/isolinux.cfg ]]
then
  echo "Chroot failed sanity check:"
  echo "Chroot is missing isolinux.cfg!"
  exit 2
fi >&2

if [[ ! -f "$ISODIR"/var/cache/sorcery/udev* ]]
then
  echo "Chroot failed sanity check:"
  echo "Chroot is missing the udev cache file!"
  exit 2
fi >&2

# The temporary dir I'll use to put the initrd files
INITRDROOT=/tmp/initrd-dir

# Dirs to look in for executables (no leading / please)
EXECDIRS=(bin sbin usr/bin usr/sbin)

#---------------------------------------------------------------------
## @param full path of binary to check
## @Stdout libraries with full path
## echos all libs that the given file is linked against (not ld-linux)
#---------------------------------------------------------------------
# Used to implicitly install linked-against-libs to the initrd with a binary
function libscan() {
  chroot $ISODIR /usr/bin/ldd "$1" |
  grep '/' |
  cut -f 2 |
  sed -e 's/.*=> //' |
  sed -e 's/ (0x.*)$//' |
  sed -e 's/^[/]//'
}

# This function gets the real library files from the symlinks returned
# by running libscan (ldd returns symlinks if that's what the binary
# links to). The leading '/' is removed for convenience.
function reallib() {
  chroot $ISODIR readlink -f $1 |
  sed -e 's/^[/]//'
}

function my_which() {
  for dir in "${EXECDIRS[@]}" ;do
    if [[ -x $dir/$1 ]] ;then
      echo "$dir/$1"
      return 0
    fi
  done
  echo "Unable to find $1 in your chroot!" >&2
  return 1
}

#---------------------------------------------------------------------
## Tries to find the given binary and copy it and its required libs
## onto the initrd at the same paths they are in the parent system.
## (working directory is assumed to be the root dir of a chroot, or /)
#---------------------------------------------------------------------
function install_prog() {
  local prog progpath
  local i
  for prog in $* ;do
    # find executable
    progpath=$(my_which $prog) &&
    # install executable (path will be relative to $ISODIR)
    cp --parents -f $progpath $INITRDROOT &&
    # install needed libs
    for i in $(libscan $progpath) ; do
      # Needed to copy both the lib and symlinks
      # Some programs (like ldconfig) rely on the symlinks
      cp --parents -f $(reallib $i) $INITRDROOT
      cp -d --parents -f $i $INITRDROOT
    done
  done
}


#---------------------------------------------------------------------
## @param path to initrd directory
## @param path to store gzip-compressed initrd image
## @Description
## This function creates a loopback-mountable filesystem from the
## given initrd and passes it through gzip compression
#---------------------------------------------------------------------
function mk_initrd_file() {
  local initrd_size tmp_file tmp_mountdir

  # Measure size of the initrd files, add 20% for e2fs overhead and safety
  initrd_size=$(du -ks ${INITRDROOT} | cut -d$'\t' -f1)
  initrd_size="$(( initrd_size + initrd_size / 5 ))"

  tmp_file="/tmp/initrd.$$"
  tmp_mountdir="/tmp/initrdmpoint.$$"

  rm -rf $tmp_file $tmp_mountdir
  # Create initrd file and filesystem
  dd if=/dev/zero of=$tmp_file bs=1024 count=$initrd_size
  mke2fs -q -b 1024 -i 1024 -F $tmp_file

  # Copy stuff into image
  mkdir -p $tmp_mountdir
  mount $tmp_file $tmp_mountdir -o loop
  cp -a $1/* $tmp_mountdir
  umount -d $tmp_mountdir

  gzip -c $tmp_file > $2

  rm -rf $tmp_file $tmp_mountdir
  echo "initrd is at $2, compressed $(du -ks $2 | cut -d$'\t' -f1)K, uncompressed ${initrd_size}K."
  if grep -q '@INITRD_SIZE@' "$ISODIR"/isolinux/isolinux.cfg
  then
    sed -i "s/@INITRD_SIZE@/$initrd_size/" "$ISODIR"/isolinux/isolinux.cfg
  else
    echo "Don't forget to adjust isolinux.cfg for the new size."
  fi
}

function install_udev() {
  local udev="$ISODIR/var/cache/udev*"
  local exclude=(init.d doc man var)

  if ! tar xf $udev "${exclude[@]/#/--exclude=}" -C "$INITRDROOT"
  then
    echo "error: could not extract $udev to $INITRDROOT"
    exit 2
  fi
}

# Find my stuff
MYDIR=$(readlink -f ${0%/*}/..)

if ! [[ -e $MYDIR/data/initrd.files ]] ;then
  echo "Failed sanity check: Cannot find data/initrd.files in my dir"
  echo "(assumed to be $MYDIR)"
  exit 2
fi >&2

rm -rf $INITRDROOT
mkdir -p $INITRDROOT

# Unless otherwise noted, this is our working directory.
pushd $ISODIR >/dev/null

# Create all dirs we need on the initrd
echo "Creating dirs..."
while read line ; do
  mkdir -p ${INITRDROOT}/${line}
done <$MYDIR/data/initrd.dirs

# Copy files onto the initrd that we need.
echo "Copying files and programs..."
while read line ; do
  # If it has a leading /, treat it as a single file
  if [[ ${line:0:1} == '/' ]] ;then
    cp -a --parents ${line:1} ${INITRDROOT}
  else
    # Otherwise, it's a binary, find it and install its libs too
    install_prog $line
  fi
done <$MYDIR/data/initrd.files

# Copy the dynamic loader over
echo "Copying over dynamic loader"
cp --parents lib/ld-2.* $INITRDROOT

# Create a static /dev
echo "Creating static dev"
pushd $INITRDROOT/dev >/dev/null
$MYDIR/data/MAKEDEV generic-nopty
popd >/dev/null

# Create an empty /var/log/dmesg so dmesg can be used
echo "Creating empty /var/log/dmesg"
touch $INITRDROOT/var/log/dmesg

# Add kernel modules that are supposed to be on the iso
echo "adding kernel modules"
mkdir -p ${INITRDROOT}/lib/modules/${KERNEL_VERSION}/kernel
pushd $ISODIR/lib/modules/${KERNEL_VERSION}/kernel >/dev/null
 while read line ; do
   cp -pr --parents ./${line} ${INITRDROOT}/lib/modules/${KERNEL_VERSION}/kernel
 done <$MYDIR/data/initrd.kernel
popd >/dev/null

# Copy module listing and other files the kernel needs, omit dirs though
echo "Copy module listing and other files"
cp -dp --parents lib/modules/$KERNEL_VERSION/* $INITRDROOT 2>/dev/null

# Finally, copy everything from the skeleton on top
echo "Copy skeleton"
cp -af $MYDIR/initrd/* ${INITRDROOT}

# Set up linker caches and symlinks
echo "Set up linker caches and symlinks"
cp sbin/ldconfig ${INITRDROOT}
chroot ${INITRDROOT} /ldconfig
rm ${INITRDROOT}/ldconfig

# create module dependencies.
echo "create module dependencies"
cp sbin/depmod ${INITRDROOT}
chroot ${INITRDROOT} /depmod ${KERNEL_VERSION}
rm -f ${INITRDROOT}/depmod

# install udev
echo "installing udev into the initrd"
install_udev

# The initrd is complete now.
echo "Make the initrd"
popd >/dev/null
mk_initrd_file $INITRDROOT "$OUTPUT"

echo "cleaning up..."
rm -rf ${INITRDROOT}
