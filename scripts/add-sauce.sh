#!/bin/bash

TEMPDIR="/tmp/sauce.$$"

FORCE=false
TYPE="bad"

function usage() {
  cat << EndUsage
Usage: $(basename $0) [-ofh] -i|-s /path/to/target

Adds the cauldron team files to the given chroot.
This script requires superuser privileges.

Required:
	-i  Use for "iso" targets

	-s  Use for "system" targets

Options:
	-f  Forces the script to add the files to the target directory, even if
	    that directory is not detected to be a proper chroot environment.

	-k KERNEL_VERSION
	    Specify the kernel version to include the blacklist modules for.
	    Defaults to the first version it finds in /lib/modules/ if not
	    specified. Only applies to "iso" targets.

	-o  Forces overwriting files in the target directory

	-h  Shows this help information
EndUsage
  exit 1
} >&2

while getopts ":fhik:os" Option
do
  case $Option in
    f ) FORCE=true ;;
    i ) TYPE="iso" ;;
    k ) KVER="$OPTARG" ;;
    o ) OVERWRITE="a" ;;
    s ) TYPE="system" ;;
    h ) usage ;;
    * ) echo "Unrecognized option." >&2 && usage ;;
  esac
done
shift $(($OPTIND - 1))

SELF="$0"

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

if [[ $TYPE == "bad" || -z $1 ]] ;then
  usage
fi

CHROOTDIR="${1%/}"

if ! $FORCE ;then
  if [[ ! -x "$CHROOTDIR"/bin/bash ]] ;then
    echo "Chroot at $CHROOTDIR failed sanity check (no bash?)"
    exit 2
  fi >&2
fi

MYDIR="$(readlink -f ${0%/*}/..)"

if ! [[ -e "$MYDIR"/base/etc/shadow ]] ;then
  echo "Failed sanity check: Cannot find base/etc/shadow in my dir"
  echo "(assumed to be $MYDIR)"
  exit 2
fi >&2

function blacklist_modules {
  local SRC="${1%/}"
  local DEST="${2%/}"

  [[ ! -d "$SRC" || ! -d "$DEST" ]] && exit 3
  mkdir -p "$DEST"/etc/modprobe.d

  find "$SRC" -name "*.ko" |
    sed 's#^.*/##' |
    sed 's#^\(.*\)\.ko$#install \1 /bin/true#' |
    sort >> "$DEST"/etc/modprobe.d/blacklist
}

if [[ $TYPE == "iso" ]] ;then
  # ensure kernel presence/sanity
  KVER=${KVER:-$(find "$CHROOTDIR"/lib/modules -mindepth 1 -maxdepth 1 -print | head -n1 | sed 's#.*/##')}
  if [[ -z $KVER || ! -d "$CHROOTDIR"/lib/modules/$KVER ]]
  then
	  echo "Kernel version not fount in chroot dir!"
	  exit 3
  fi
fi

# make sure we start with a clean TEMPDIR each run
 rm -rf "$TEMPDIR"
 mkdir -m 0700 "$TEMPDIR"

# add the contents of base, which are files that
# should go onto both iso and system chroots
# this is mostly /etc content
 echo "Copying base files to staging area"
 cp -a "$MYDIR"/base/* "$TEMPDIR"/

# ISO Sauce
if [[ $TYPE == "iso" ]] ;then
  # add the relevant modules to the blacklist
  echo "Blacklisting kernel modules in staging area"
  blacklist_modules "$CHROOTDIR/lib/modules/$KVER/kernel/drivers/video" "$TEMPDIR"

  # copy everything from the cauldron repo iso dir
  # into the TEMPDIR staging area
  echo "Copying ISO files to staging area"
  cp -a "$MYDIR"/iso/* "$TEMPDIR"/

  # strip boot/grub from the staging area, since the ISO doesn't need this file
  rm -fr "$TEMPDIR"/boot/grub
fi

# System Sauce
if [[ $TYPE == "system" ]]
then
  # make sure that the grub stage files are available in /boot
  # by copying them from CHROOTDIR (system) into the /boot dir
  # in our TEMPDIR staging area
  [[ -d "$CHROOTDIR"/usr/lib/grub/i386-pc ]] && cp -a "$CHROOTDIR"/usr/lib/grub/i386-pc/* "$TEMPDIR"/boot/grub/
fi

# ==== FIXUP starts here ====
 echo "Setting permissions on staged files"
 chown -R 0:0 "$TEMPDIR"/
 chmod -R u=rwX,go=u-w "$TEMPDIR"/
 chmod 0600 "$TEMPDIR"/etc/shadow
# ==== end fixup ====

# Get a list of all files we want to install
echo "Installing staged files to $CHROOTDIR"
for i in $(find "$TEMPDIR" -mindepth 1 -print)
do
  FILE="${i#$TEMPDIR/}"
  # If FILE is a directory, mkdir in CHROOTDIR
  # This is safe even if the dir already exists
  if [[ -d $i ]]
  then
     mkdir -p "$CHROOTDIR/$FILE"
    continue
  fi

  # For each file, check to see if it already
  # exists in CHROOTDIR, and if so prompt if
  # we should overwrite or not. If
  # 'a' is passed then skip the prompting and
  # just overwrite. Else, if 'y' is passed
  # overwrite that file and prompt on next.
  # Since this is checked via an env var,
  # you can be clever and run this as
  # OVERWRITE='a' add-sauce.sh [-i|-s] CHROOTDIR
  if [[ -e "$CHROOTDIR/$FILE" && $OVERWRITE != a ]]
  then
    echo -n "Overwrite ${FILE}? [yna] "
    read -n1 OVERWRITE
    echo ""
    if [[ $OVERWRITE == y ]]
    then
       cp -a "$TEMPDIR/$FILE" "$CHROOTDIR/$FILE"
    fi
  else
     cp -a "$TEMPDIR/$FILE" "$CHROOTDIR/$FILE"
  fi
done

# ensure that ld has an up-to-date cache
echo "Running ldconfig in $CHROOTDIR"
"${0%/*}"/cauldronchr.sh -d "$CHROOTDIR" /sbin/ldconfig ||
echo "error: ldconfig failed in $CHROOTDIR"

# clean up
rm -rf "$TEMPDIR"

