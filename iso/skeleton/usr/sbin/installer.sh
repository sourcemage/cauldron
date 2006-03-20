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

# Color definitions
COLOR_next_required="\Zb\Z7" # bright white
COLOR_required="\Z4" # blue
COLOR_optional="\Zb\Z2" # bright green
COLOR_reconfigure="\Z2" # green
COLOR_not_possible="\Zb\Z0" # grey
COLOR_misc="\Zn" # black
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
  if check_dependency disk-root && confirm \
      "Do you want to boot into your new system directly? (experimental)"\
      --defaultno ;then
    export ACTION="pivot_root"
    export ROOTDEV=$(get_dependency disk-root)
  else
    export ACTION="reboot"
    if [[ -e /etc/cddev ]] ;then
      CDDEV=$(</etc/cddev)
    else
      CDDEV=$(cat /proc/cmdline | sed 's/.*root=//' | cut -d' ' -f1)
    fi
    export CDDEV
  fi

  exec shutdown -h -q now # -h because that one calls halt_action
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

  # first unmount already mounted filesystems 
  local mounted_part
  for mounted_part in `mount | awk ' { print $3}' | grep /mnt/root | sort -r`
    do umount -f $mounted_part 2>/dev/null
  done
  swapoff -a

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

  main_move_on "init"

  while true ;do

    local ICOMMAND
    local MENU_DESCRIPTION="Here are the steps for the install. [*] denotes an optional step.
All other steps are required. Entries should be followed in the order in
which they appear."
    ICOMMAND=$(run_dialog --colors                  \
          --title "Source Mage GNU/Linux installer" \
          --nocancel --default-item $CURRENT_MAIN   \
          --item-help --menu "$MENU_DESCRIPTION"    \
          0 0 0                                     \
          "A" "${COLOR_MAIN_INTRO}[*]Introduction"    \
              "Read about the advantages of using Source Mage GNU/Linux" \
          "?" "${COLOR_MAIN_HELP}[*]Installation and help notes" \
              "A help text on the installer" \
          "B" "${COLOR_MAIN_NLS}[*]Pre-installation defaults settings" \
              "Select default language, keymap, font and editor" \
          "C" "${COLOR_MAIN_DISK}Disk Structure" \
              "Partition, format, and mount your disk" \
          "D" "${COLOR_MAIN_START}Start Installation" \
              "Start everything, no going back to mounting now" \
          "E" "${COLOR_MAIN_TIME}[*]Select Timezone" \
              "Select this box's timezone" \
          "F" "${COLOR_MAIN_ARCH}[*]Architecture Optimizations" \
              "Select Architecture and Optimizations" \
          "G" "${COLOR_MAIN_KERNEL}Select Linux Kernel" \
              "Determine wether to compile or install the default kernel" \
          "H" "${COLOR_MAIN_LOG}[*]Configure Log System" \
              "Select a daemon for system logging, or none!" \
          "I" "${COLOR_MAIN_BOOT}Configure Bootloader" \
              "Configure a bootloader for this box" \
          "J" "${COLOR_MAIN_NET}Configure Networking" \
               "Configure this box's network" \
          "K" "${COLOR_MAIN_MISC}Misc. Configuration" \
              "Select some extra spells to install and configure a bit." \
          "L" "${COLOR_MAIN_FINISH}Install Source Mage GNU/Linux" \
              "Install all left to be done" \
          "M" "${COLOR_MAIN_SERVICES}[*]Choose Services to Run at Boot (expert)" \
              "Select which services to start at boot" \
          "X" "${COLOR_MAIN_DONE}Done" \
              "Exit! Done! Finito!" \
          "S" "${COLOR_MAIN_SHELL}[*]Shell" \
              "Shell out perhaps to load modules" \
          "R" "${COLOR_MAIN_RESTART}[*]Restart Installation" \
              "Resets everything and begins installation again" \
          "Z" "${COLOR_MAIN_DEBUG}[*]Debug Menu" \
              "Change debugging settings" )

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
      main_move_on "$ICOMMAND"
    else
      debug_log "main" 1 "Failed to run menu entry $ICOMMAND"
      echo "Detecting an error, not moving forward in the menu." >&2
      debug_enter "main" 2
    fi

  done
}

# Runs whatever wheels need to be run to mark the given step
# as done and move on to the next one
main_move_on() {
  case $1 in
    "init")
           CURRENT_MAIN="B"
           main_colorize misc INTRO HELP
           main_colorize next_required DISK
           main_colorize optional NLS
           # FIXME: This is not technically correct, some of those
           # steps are already possible thanks to $FINALFILES.
           main_colorize not_possible START TIME ARCH KERNEL LOG BOOT NET
           main_colorize not_possible MISC FINISH SERVICES
           main_colorize required DONE
           main_colorize misc SHELL RESTART DEBUG
         ;;
    A) CURRENT_MAIN="B"  ;;
    B)
      CURRENT_MAIN="C"
      main_colorize reconfigure NLS
    ;;
    C)
      CURRENT_MAIN="D"
      main_colorize reconfigure DISK
      main_colorize next_required START
      main_colorize optional TIME ARCH LOG
    ;;
    D)
      CURRENT_MAIN="E"
      main_colorize not_possible START DISK
      main_colorize next_required KERNEL
      main_colorize required NET
    ;;
    E)
      CURRENT_MAIN="F"
      main_colorize reconfigure TIME
    ;;
    F)
      CURRENT_MAIN="G"
      main_colorize reconfigure ARCH
    ;;
    G)
      CURRENT_MAIN="H"
      main_colorize reconfigure KERNEL
      main_colorize next_required BOOT
    ;;
    H)
      CURRENT_MAIN="I"
      main_colorize reconfigure LOG
    ;;
    I)
      CURRENT_MAIN="J"
      main_colorize next_required NET
      main_colorize reconfigure BOOT
    ;;
    J)
      CURRENT_MAIN="K"
      main_colorize next_required MISC
      main_colorize reconfigure NET
    ;;
    K)
      CURRENT_MAIN="L"
      main_colorize next_required FINISH
      main_colorize reconfigure MISC
    ;;
    L)
      CURRENT_MAIN="X"
      main_colorize not_possible NLS TIME ARCH KERNEL LOG BOOT NET MISC FINISH
      main_colorize next_required DONE
      main_colorize reconfigure SERVICES;;
    M) CURRENT_MAIN="X"  ;;
    X) true ;; #huh, wtf? You're supposed to just have rebooted the box...
    R) CURRENT_MAIN="B"  ;; #reset the installer
    *) `dialog --infobox "HOLY CRAPOLA got $1 for a menu item" 10 60; sleep 2`;;
  esac
}

# @args $1 color to set steps to
# @args $* steps to colorize
main_colorize() {
  local color_name="COLOR_$1"
  local step
  shift
  for step in "$@" ;do
    eval "COLOR_MAIN_$step=\$$color_name"
  done
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
