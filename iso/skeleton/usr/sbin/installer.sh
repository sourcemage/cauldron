#!/bin/sh
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
    --msgbox "${MSG}" 9 60

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
    --msgbox "${MSG}" 18 60

    return 0
}



#goodbye: the finishing function. Copy the debug log if theres a certain
# file in the /tmp dir. then ask to reboot.
# SECTION: ???
final_screen() {
    # copy the install-debug log 
    if [ -d ${TARGET}/var/log ] && [ -s /tmp/installer-debug ]
      then cp -f $INSTALLER_DEBUG \
        ${TARGET}/var/log/SMGL-$INSTALLER_VERSION-install.log
    fi

    PROMPT="Reboot now?" 
    if  confirm  "${PROMPT}";  then
        exec shutdown -r -q now
    fi
}

# shells out
# SECTION: MISC
shell() {

  echo  "Press CTRL-D or type exit to return to the installer"
  /bin/bash -l

}

# toggles a confirm variable
# SECTION: MISC
toggle_confirm()  {

  [  -n  "$CONFIRM"  ]  &&
  unset  CONFIRM        ||
  CONFIRM="on"

}

#displays the intallation help file
# SECTION: MISC
display_install_help()  {

  run_dialog --cr-wrap --textbox $DATA_DIR/install.guide  21 60
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
  debug_log "main" 1 "Resetting installer"
  swapoff -a

  # reset these to the defaults
  CONFIRM=on
  DEBUG=no

  # reset depends stuff
  rm -f $DEPENDS_DIR/*

  # reset spellinstaller stuff
  rm -rf $SI_QUEUE_DIR
}

#toggles the debug switch
# SECTION: MISC
toggle_debug() {

  if [ "${DEBUG}" = "yes" ]; then
    rm -f $SI_QUEUE_DIR/debug
    DEBUG="no"
  else
    mkdir -p $SI_QUEUE_DIR
    touch $SI_QUEUE_DIR/debug # Debug proper usage of si_wait
    rm -f $SI_QUEUE_DIR/force_run
    DEBUG="yes"
  fi

  echo "DEBUG=${DEBUG}"
  press_enter

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
          8 60 0                                    \
          "A" "[*]Introduction" "Read about the advantages of using Source Mage GNU/Linux" \
          "?" "[*]Installation and help notes" "A help text on the installer" \
          "B" "[*]Native Language Support" "Select default language, keymap, and console fonts" \
          "C" "Disk Structure" "Partition, format, and mount your disk" \
          "D" "Select Timezone" "Select this box's timezone" \
          "E" "[*]Architecture Optimizations" "Select Architecture and Optimizations" \
          "F" "Select Linux Kernel" "Determine wether to compile or install the default kernel" \
          "G" "Configure Log System" "Select a daemon for system logging, or none!" \
          "H" "Configure Bootloader" "Configure a bootloader for this box" \
          "I" "Configure Networking" "Configure this box's network" \
          "J" "Misc. Configuration" "Select some extra spells to install and configure a bit." \
          "K" "Install Source Mage GNU/Linux" "Install all left to be done" \
          "L" "[*]Choose Services to Run at Boot (expert)" "Select which services to start at boot" \
          "X" "Done" "Exit! Done! Finito!" \
          "S" "[*]Shell" "Shell out perhaps to load modules" \
          "T" "[*]Toggle Confirm" "Toggles display of prompts. Do NOT use." \
          "R" "[*]Restart Installation" "Resets everything and begins installation again" \
          "Z" "[*]Toggle Debug" "Toggles the debug flag" )

    case $ICOMMAND in
      A) intro_screen     ;;
      B) nls_screen       ;;
      C) disk_structure_screen ;;
      D) timezone_screen  ;;
      E) arch_screen      ;;
      F) kernel_screen    ;;
      G) logger_screen    ;;
      H) bootloader_screen ;;
      I) network_screen   ;;
      J) optional_screen  ;;
      K) install_screen   ;;
      L) services_screen  ;; # Yes, works on the installed files and does
# nothing else, so has to be run after target is fully set up.
      X) final_screen     ;;
      S) shell            ;;
      T) toggle_confirm   ;;
      R) reset_installer  ;;
      Z) toggle_debug     ;;
      ?) display_install_help ;;
    esac

    RETURNVALUE=$?

    if [[ $RETURNVALUE == 0 ]]; then
      #movin on!
      increment_menu_pointer $ICOMMAND
    else
      run_dialog --infobox "DEBUG: not moving forward" 10 60
      sleep 1
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
    C) RETVALUE="D"
      setup_target
      ;;
    D) RETVALUE="E"  ;;
    E) RETVALUE="F"  ;;
    F) RETVALUE="G"  ;;
    G) RETVALUE="H"  ;;
    H) RETVALUE="I"  ;;
    I) RETVALUE="J"  ;;
    J) RETVALUE="K"  ;;
    K) RETVALUE="X"  ;;
    L) RETVALUE="X"  ;;
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
  CONFIRM=on

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

# notes on dialog:
# General warning about dialog --radiolist. Since the result is
# enclosed with spurious ".
# For instance:
#
# dialog --stdout --radiolist radiolist 9 60 2 \
#  "grub" "grub text" "on" \
#  "lilo" "lilo text" "off"
#
# will return "grub" instead of grub.
# Use --single-quoted to get the result without (!?!) any quotes.
#
# dialog --yesno     : add 4 to get height
# dialog --msgbox    : add 5 to get height
# dialog --menu      : add 6 to get height (let menu-height to always be 0)
# dialog --radiolist : add 6 to get height (let list-height to always be 0)
# dialog --checklist : add 6 to get height (let list-height to always be 0)
# dialog --inputbox  : add 7 to get height

# do some initial config things
# TODO: add these to a function
if [ -f $STATE_DIR/version ]; then
  . $STATE_DIR/version 
else
  INSTALLER_VERSION=`date +%Y%m%d`-debug
  SORCERY_VERSION=stable #wild guess
  GRIMOIRE_VERSION=stable
fi

echo "INSTALLER (RE)STARTING" 1>&2

export DIALOGRC=/etc/sorcery/dialogrc # yoohoo! sorcery color scheme!

DIALOG=( "dialog" "--backtitle" \
         "Source Mage GNU/Linux Installer v. ${INSTALLER_VERSION}" \
         "--stdout" "--trim")

trap  "true"  INT QUIT

# start the installation process
main "$@"
