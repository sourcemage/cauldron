#!/bin/bash
########################################################################
# Copyright (c) 2005 Source Mage GNU/Linux Team <www.sourcemage.org>   #
########################################################################
#                                                                      #
# This program is free software; you can redistribute it and/or modify #
# it under the terms of the GNU General Public License as published by #
# the Free Software Foundation; either version 2 of the License, or    #
# (at your option) any later version.                                  #
#                                                                      #
#   This program is distributed in the hope that it will be useful,    #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of     #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the      #
#   GNU General Public License for more details.                       #
#                                                                      #
#  You should have received a copy of the GNU General Public License   #
#  along with this program; if not, write to the Free Software         #
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston,               #
#  MA  02111-1307  USA                                                 #
#                                                                      #
########################################################################
#         This is a menu driven process of                             #
#  installing from the Source Mage GNU/Linux ISO                       #
#                                                                      #
########################################################################

# Files that should be provided for this installer to work:
# ${DATA_DIR}/directories - Directories to force create (newinstall)
# ${STATE_DIR}/optionalSpellList - list of optional spells with description
#                                  (optionalSpell)

# ------------------ GLOBAL Variables ----------------------------------
# DATA_DIR: dir containing static data
# STATE_DIR: dir containing pre-generated lists etc.
# DEPENDS_DIR: internal directory for depends
# FINALFILES: Directory containing e.g. /etc files that should be copied
#   on when all is done (to prevent getting overwritten by spell files)
# TARGET: Directory to install to

DATA_DIR=/usr/share/smgl.install
MODULE_DIR=$DATA_DIR/modules
TEMPLATE_DIR=$DATA_DIR/templates
STATE_DIR=/var/lib/smgl.install

TMP_DIR=/tmp
DEPENDS_DIR=$TMP_DIR/installer_depends
FINALFILES=$TMP_DIR/finalfiles
INSTALLER_DEBUG=$TMP_DIR/installer_debug
# ---------------END GLOBAL Variables ----------------------------------

#source all the modules to load everything...
#TODO: perhaps source things only when needed?
for inst_MODULE in $MODULE_DIR/* ;do
  . $inst_MODULE #This has to be a global :/
done

#introduction: don't remember ever seeing this do anything...
# SECTION: MISC
intro_screen()  {

  local MSG="The purpose of Source Mage GNU/Linux is to return
control to System Administrators that the wizards and
maintainers of modern distributions have steadily
chipped away."

  run_dialog --title "Welcome to Source Mage GNU/Linux" \
    --msgbox "${MSG}" 0 0

  local MSG="Source Mage GNU/Linux empowers System Administrators
to choose:

  the architecture that programs are compiled for, the
  dependencies a program is compiled with, compiler
  optimizations, and compile time options.

And it provides the conveniences of:

  command line and menu driven package management,
  ASCII configuration and data files, FHS 2.2
  compliant filesystem hierarchy, parallel simpleinit
  and networking."

  run_dialog  --cr-wrap                             \
    --title  "The Benefits of Source Mage GNU/Linux"  \
    --msgbox "${MSG}" 0 0

  run_dialog --cr-wrap             \
    --title "About this installer" \
    --msgbox                       \
"This installer is developed by the Source Mage
Cauldron team. Feedback is very welcome under
bugs.sourcemage.org, or on IRC on irc.freenode.net,
channel #sourcemage-cauldron.

This installer installs spells in the background,
you can view progress on tty2 if you want (press
ALT+F2 or ALT+RightArrow).

There's a help file accessible from the main menu
on this installer, or on tty6 (ALT-F6 or
ALT+LeftArrow).
We hope you'll enjoy using our installer! ;-)" 0 0

    return 0
}



#goodbye: the finishing function. Copy the debug log if theres a certain
# file in the /tmp dir. then ask to reboot.
# SECTION: ???
final_screen() {

  # This is the place for release-note bigass warnings
  run_dialog --cr-wrap --msgbox \
"Once you have booted your new system, it's recommmended to:
* ensure that networking is up
* run \"sorcery update\" to update the sorcery scripts
* run \"scribe update\" to update the spell lists
* configure sorcery (run \"sorcery\", go to Options)
* run \"sorcery rebuild\" to build everything with your
  chosen optimizations" 0 0

    # copy the install-debug log 
  if [ -d ${TARGET}/var/log ] && [ -s $INSTALLER_DEBUG ] ;then
    cp $INSTALLER_DEBUG ${TARGET}/var/log/SMGL-$INSTALLER_VERSION-install.log
    if grep -q 'ERROR' $INSTALLER_DEBUG ;then
      display_message \
"There appear to have been errors during \
the install. In order to help debugging them, \
could you please somehow mail the file
/var/log/SMGL-$INSTALLER_VERSION-install.log
(on the installed system) \
to iso@sourcemage.org? Please include \
\"[ISO debugging log]\" in the e-mail subject."
    fi
  fi

  exec shutdown -r -q now
}

# shells out
# SECTION: MISC
shell() {

  echo  "Press CTRL-D or type exit to return to the installer"
  /bin/login-shell.sh

}

#displays the intallation help file
# SECTION: MISC
display_install_help()  {

  run_dialog --cr-wrap --textbox $DATA_DIR/install.guide  0 0
  return 0
}

# resets every variable and restarts the installation
# SECTION: MISC
reset_installer() {
# unset all these
#common
  unset EDITOR
  unset LANG
  unset PLACE # TODO: left-over global from RAID, clean up
  unset RAIDLEVEL
  unset RAID_PARTS
  unset RD_PARTS
  unset RD_DISC
  unset ind_disk
  unset part
  unset RDEV # end left-overs

  # first unmount already mounted filesystems 
  local mounted_part
  for mounted_part in `mount | awk ' { print $3}' | grep /mnt/root | sort -r`
    do umount -f $mounted_part 2>/dev/null
  done
  
  # then when unmounted, stop raid arrays
  for RDEV in `grep raiddev /etc/raidtab | awk '{print $2}'`;
    do raidstop $RDEV
  done

  # now remove raid temporary files so the restart works on all partitions
  rm -f /tmp/raid*
  rm -f /etc/raidtab
  rm -f /tmp/fstab
  # add restart to installer-debug log if it exists
  debug_log "main" 0 "Resetting installer"
  swapoff -a

  # reset depends stuff
  rm -f $DEPENDS_DIR/*

  rm -rf $FINALFILES/*
  cp --parents /etc/sysconfig/* ${FINALFILES}

  # reset spellinstaller stuff
  rm -rf $SI_QUEUE_DIR
}

#displays the installer menu
display_install_menu() {

# TODO: move kernel down a bit, since configuring now happens inside
# the "select" step

  local CURRENT_MAIN="B";

  while true ;do

    local ICOMMAND
    local MENU_DESCRIPTION="Here are the steps for the install. [*] denotes an optional step.
All other steps are required. Entries should be followed in the order in
which they appear."
    ICOMMAND=$(run_dialog                            \
          --title "Source Mage GNU/Linux installer" \
          --nocancel --default-item $CURRENT_MAIN   \
          --item-help --menu "$MENU_DESCRIPTION"    \
          0 0 0                                    \
          "A" "[*]Introduction" "Read about the advantages of using Source Mage GNU/Linux" \
          "?" "[*]Installation and help notes" "A help text on the installer" \
          "B" "[*]Pre-installation defaults settings" "Select default language, keymap, font and editor" \
          "C" "Disk Structure" "Partition, format, and mount your disk" \
          "D" "Start Installation" "Start everything, no going back to mounting now" \
          "E" "[*]Select Timezone" "Select this box's timezone" \
          "F" "[*]Architecture Optimizations" "Select Architecture and Optimizations" \
          "G" "Select Linux Kernel" "Determine wether to compile or install the default kernel" \
          "H" "[*]Configure Log System" "Select a daemon for system logging, or none!" \
          "I" "Configure Bootloader" "Configure a bootloader for this box" \
          "J" "Configure Networking" "Configure this box's network" \
          "K" "Misc. Configuration" "Select some extra spells to install and configure a bit." \
          "L" "Install Source Mage GNU/Linux" "Install all left to be done" \
          "M" "[*]Choose Services to Run at Boot (expert)" "Select which services to start at boot" \
          "X" "Done" "Exit! Done! Finito!" \
          "S" "[*]Shell" "Shell out perhaps to load modules" \
          "R" "[*]Restart Installation" "Resets everything and begins installation again" \
          "Z" "[*]Debug Menu" "Change debugging settings" )

    [[ -z $ICOMMAND ]] && continue

    case $ICOMMAND in
      A) intro_screen     ;;
      B) nls_screen       ;;
      C) disk_structure_screen ;;
      D) setup_target     ;;
      E) timezone_screen  ;;
      F) arch_screen      ;;
      G) kernel_screen    ;;
      H) logger_screen    ;;
      I) bootloader_screen ;;
      J) network_screen   ;;
      K) optional_screen  ;;
      L) install_screen   ;;
      M) services_screen  ;; # Yes, works on the installed files and does
# nothing else, so has to be run after target is fully set up.
      X) final_screen     ;;
      S) shell            ;;
      R) reset_installer  ;;
      Z) debug_screen     ;;
      ?) display_install_help ;;
    esac

    RETURNVALUE=$?

    if [[ $RETURNVALUE == 0 ]]; then
      #movin on!
      increment_menu_pointer $ICOMMAND
    else
      debug_log "main" 1 "Failed to run menu entry $ICOMMAND"
      echo "Detecting an error, not moving forward in the menu." >&2
      debug_enter "main" 2
    fi

  done
}

#simply returns a value pointing to the next item in the menu list
# used to make the installer self motivated
# also runs the background functions
# all the TODOs here should be back grounded
increment_menu_pointer() {
  local RETVALUE="A";
  case $1 in
    A) RETVALUE="B"  ;;
    B) RETVALUE="C"  ;;
    C) RETVALUE="D"  ;;
    D) RETVALUE="E"  ;;
    E) RETVALUE="F"  ;;
    F) RETVALUE="G"  ;;
    G) RETVALUE="H"  ;;
    H) RETVALUE="I"  ;;
    I) RETVALUE="J"  ;;
    J) RETVALUE="K"  ;;
    K) RETVALUE="L"  ;;
    L) RETVALUE="X"  ;;
    M) RETVALUE="X"  ;;
    R) RETVALUE="B"  ;; #reset the installer
    *) `dialog --infobox "HOLY CRAPOLA got $1 for a menu item" 10 60; sleep 2`;;
  esac

  CURRENT_MAIN=$RETVALUE
}

# sets up the system for the install process
# SECTION: INSTALLER
main()  {

  export  PATH="/bin:/usr/bin:/sbin:/usr/sbin"
  export  HOME="/root"

# mount /proc (needed later for /proc/partitions for instance)

  mount -t proc proc /proc

# mount /dev (is it needed)
# mount -t devfs devfs /dev

  [ -z $ARCH ] && ARCH=`uname -m`

# TARGET is the mount point where Source Mage will be installed it
# should be defined before running this script or it will default to
# /mnt/root. Since this script is intended to run from a CDROM (ie
# read-only filesystem), the directory must already exists.

  [ -z $TARGET ] && TARGET=/mnt/root

# check for TARGET
  if [ ! -d "${TARGET}" ]; then
    echo "TARGET=${TARGET} is not an existing directory."
    exit 1
  fi

  mkdir -p $DEPENDS_DIR $FINALFILES
  cp --parents /etc/sysconfig/* ${FINALFILES}

  if [[ "$1" == "-e" ]] ;then
    return # to just fetch environment
  fi

  init_debug

  display_install_menu

}

#
# this script really starts here
#

# do some initial config things
# TODO: add these to a function
if [ -f $STATE_DIR/version ]; then
  . $STATE_DIR/version 
else
  INSTALLER_VERSION=inofficial-debug
  SORCERY_VERSION=stable #wild guess
  GRIMOIRE_VERSION=stable
  KERNEL_VERSION=$(uname -r)
fi

echo "INSTALLER (RE)STARTING" 1>&2

export DIALOGRC=/etc/sorcery/dialogrc # yoohoo! sorcery color scheme!

trap  "true"  INT QUIT

# start the installation process
main "$@"
