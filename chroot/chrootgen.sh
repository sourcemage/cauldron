#!/bin/bash
#---------------------------------------------------------------------
#Copyright (C) 2005 Andrew Stitt astitt@sourcemage.org
#Copyright (C) 2005 Source Mage GNU/Linux (www.sourcemage.org)
#
#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either
#version 2 of the License, or (at your option) any later
#version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#---------------------------------------------------------------------

#---------------------------------------------------------------------
##
## This script can backup/restore sorcery configuration sets.
## You can use it to generate a chroot and have reproducable casts by
## using the same configuration set.
##
#---------------------------------------------------------------------


. /etc/sorcery/config

#---------------------------------------------------------------------
## A usage message, someday.
#---------------------------------------------------------------------
function usage() {
cat << EOF

$0 [--option value ...] task

This command can be used to backup sorcery/spell configuration data and
then restore it. The idea is to have defined sets of data, load them
onto a system, and perform some commands. The result is that all relavent
configuration questions and options will have already been determined. So
a user should be able to achieve reproducable results.

Quick start guide:
To make a new chroot from nothing:
chrootgen --chroot_dir /path/to/chroot --config_dir /tmp/new_config \\
          --backup_dir /tmp/backup_configs fresh

Follow the instructions, the new configset is in /tmp/new_config.
If bad things happen, recover your old system with:
chrootgen --config_dir /tmp/backup_configs restore

To make a new chroot from an existing configset:
chrootgen --chroot_dir /path/to/chroot --config_dir /path/to/configset \\
          --backup_dir /tmp/backup_configs recreate

The following options are supported:


--chroot_dir	Global prefix for all operations, use this to transfer
		config sets to a directory that you will later chroot into.

--state_root	State data will be copied under this directory, use this
		if you plan on generating a chroot you will later chroot into.
		A restore operation will set this value in sorcery config.

--install_root	A restore operation will set INSTALL_ROOT to this value
		in sorcery config.
--restore_dir	Pull config data from here on a restore operation.
--backup_dir	Backup data here on a backup operation.
--config_dir	This directory if specified will be used for both backup
		and restore.
--fake		Dont actually make the chroot.

The following commands are supported:

fresh		Setup a fresh chroot in the specified directory, do all
		the special steps and apply config backup/restore in
		the right ways. This serves as a command itself.

recreate        Restore data from the given restore directory, checksum
		the data, generate the chroot, re-checksum the data. If
		the data has changed ask if the user wants to create a
		new backup.

The previous two tasks are wrappers over these tasks, and some other things.

backup		Backup the config data to the specified directory.
restore		Restore config data from the specified directory.

cksum_cfg	Checksum the data on the system.
generate	Do whatever is necessary to generate a chroot, currently
		this is simply cast -c basesystem

bind		Mount /dev, /proc and /sys /var/spool/sorcery in the chroot.
unbind		Undo a bind action.
populate	Copy in skeleton data and do other basic chroot setup.

The data used in config sets consist of sorcery config data
(/etc/sorcery/local) except for the grimoires file, the persistent and
spell_config stores ($STATE_ROOT/etc/sorcery/local/depends), and the
dependency data ($STATE_ROOT/var/state/sorcery/depends).

EOF
}

#---------------------------------------------------------------------
## Home to all default values that may be overridden by cli args.
#---------------------------------------------------------------------
function default_config() {
  SORCERY_LOCAL_CONFIG_DIR=etc/sorcery/local
  SORCERY_PERSIST_DIR=etc/sorcery/local/depends
  SORCERY_STATE_DIR=var/state/sorcery
  CHROOT_DIR=""
  STATE_ROOT=""
  BACKUP_DIR=/root/backup.cfgs
  CONFIG_DIR=""
  TASK=none
}

#---------------------------------------------------------------------
## Parse command line arguments.
#---------------------------------------------------------------------
function parse_args() {
  while [ -n "$1" ]; do
    if echo $1 | grep -q -- "^-"; then
      case $1 in
        --chroot_dir) CHROOT_DIR=$2 ; shift;;
        --state_root) STATE_ROOT=$2 ; shift;;
      --install_root) INSTALL_ROOT=$2 ; shift;;
        --config_dir) BACKUP_DIR=$2; CONFIG_DIR=$2 ; shift;;
       --restore_dir) CONFIG_DIR=$2 ; shift;;
        --backup_dir) BACKUP_DIR=$2 ; shift;;
              --fake) FAKE=yes;;
              --help) usage ; exit  ;;
                   *) echo $1 is not a valid option;usage ; exit 1;;
      esac
    else
      TASK=$1
    fi
    shift
  done
}


#---------------------------------------------------------------------
## Any sanity checks go here, currently just ensure that we are root.
#---------------------------------------------------------------------
function sanity_check() {
  if [[ $UID != 0 ]] ; then
    echo "You must be root"
    return 1
  fi
}

#---------------------------------------------------------------------
## Backup config and depends data.
#---------------------------------------------------------------------
function backup_sorcery() {
  local CHROOT_DIR=$1
  local STATE_ROOT=$2
  local SORCERY_BACKUP_DIR=$3
  if [[ $SORCERY_BACKUP_DIR != "" ]] ; then
    rm -rf $SORCERY_BACKUP_DIR

    mkdir -p ${SORCERY_BACKUP_DIR}/config/$SORCERY_LOCAL_CONFIG_DIR &&
    mkdir -p ${SORCERY_BACKUP_DIR}/state/$SORCERY_LOCAL_CONFIG_DIR &&
    mkdir -p ${SORCERY_BACKUP_DIR}/state/$SORCERY_STATE_DIR || {
      echo "failed to make backup dirs"
      return 1
    }

    if test -d /$SORCERY_LOCAL_CONFIG_DIR; then
      cp -fa /$SORCERY_LOCAL_CONFIG_DIR/* \
        $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_CONFIG_DIR || {
        echo "Failed to backup config data"
        return 1
      }
      # this is per-site customized
      rm -f $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_CONFIG_DIR/roots
      # the local copy of this is kept
      rm -f $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_CONFIG_DIR/grimoire
      rm -f $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_CONFIG_DIR/grimoire.backup
      # this is backed up elsewhere
      rm -rf $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_CONFIG_DIR/depends
   else
     echo "no sorcery config data"
   fi

    if test -d $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR/depends; then
      cp -fa $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR/depends \
             ${SORCERY_BACKUP_DIR}/state/$SORCERY_LOCAL_CONFIG_DIR || {
        echo "failed to backup persistent data"
        return 1
      }
    else
      echo "no persistent data"
    fi
    if test -f $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR/depends ; then
      cp $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR/depends \
         $SORCERY_BACKUP_DIR/state/$SORCERY_STATE_DIR/depends || {
        echo "Failed to backup depends data"
        return 1
      }
    else
      echo "no depends data"
    fi
  else
    echo "No backup directory!"
  fi
  echo "backup complete"
}

#---------------------------------------------------------------------
## Restore config and depends data.
#---------------------------------------------------------------------
function restore_sorcery() {
  local CHROOT_DIR=$1
  local STATE_ROOT=$2
  local INSTALL_ROOT=$3
  local SORCERY_BACKUP_DIR=$4
  if [[ $SORCERY_BACKUP_DIR != "" ]] ; then
    # restore config values
    mkdir -p $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR
    cd $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR
    ls|grep -v depends|grep -v grimoire|xargs rm -rf
    cd - &>/dev/null
    if test -d $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_DIR; then
      cp -fa $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_CONFIG_DIR/* \
             $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR
    else
      echo "no config data to restore"
    fi

    # restore persistent vars
    mkdir -p $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR
    cd $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR
    rm -rf depends
    cd - &>/dev/null
    if test -d $SORCERY_BACKUP_DIR/state/$SORCERY_LOCAL_CONFIG_DIR/depends; then
      cp -fa $SORCERY_BACKUP_DIR/state/$SORCERY_LOCAL_CONFIG_DIR/depends \
             $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR
    else
      echo "no persistent data to restore"
    fi

    # restore depends data
    mkdir -p $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR
    rm -f $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR/depends
    if test -f $SORCERY_BACKUP_DIR/state/$SORCERY_STATE_DIR/depends ; then
      cp $SORCERY_BACKUP_DIR/state/$SORCERY_STATE_DIR/depends \
         $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR/depends
    else
      echo "no depends data to restore"
    fi
  else
    echo "no directory to restore from!"
  fi
  setup_skeleton "$CHROOT_DIR" "$INSTALL_ROOT" "$STATE_ROOT"
}

function clean_slate() {
  local CHROOT_DIR=$1
  local STATE_ROOT=$2
  local INSTALL_ROOT=$3

  # config stuff
  mkdir -p $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR
  cd $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR
  ls|grep -v depends|grep -v grimoire|xargs rm -rf
  cd - &>/dev/null

  # persistent vars
  mkdir -p $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR
  cd $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR
  rm -rf depends
  cd - &>/dev/null

  # restore depends data
  mkdir -p $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR
  rm -f $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR/depends
  setup_skeleton "$CHROOT_DIR" "$INSTALL_ROOT" "$STATE_ROOT"
}

function setup_skeleton() {
  local CHROOT_DIR=$1
  local INSTALL_ROOT=$2
  local STATE_ROOT=$3

  # setup specific vars
  mkdir -p $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR
  touch $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR/roots
  modify_config $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR/roots \
                STATE_ROOT $STATE_ROOT
  modify_config $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR/roots \
                INSTALL_ROOT $INSTALL_ROOT
  # funny things happen when these arent there...
  touch $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR/config
  chmod +x $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR/config
  touch $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR/compile_config
  chmod +x $CHROOT_DIR/$SORCERY_LOCAL_CONFIG_DIR/compile_config
}

#---------------------------------------------------------------------
## Checksum system configs, one can also checksum a backed-up config
## set if $CHROOT_DIR points there.
#---------------------------------------------------------------------
function cksum_bkp() {
  local CHROOT_DIR=$1
  local STATE_ROOT=$2
  {
    # sort each thing individually so the overall order is preserved
    find $SORCERY_BACKUP_DIR/config/$SORCERY_LOCAL_CONFIG_DIR \
       -type f -not -name grimoire -not -path '*/depends/*'  -print | sort
    find $SORCERY_BACKUP_DIR/state/$SORCERY_LOCAL_CONFIG_DIR/depends -type f \
                                                                    | sort
    find $SORCERY_BACKUP_DIR/state/$SORCERY_STATE_DIR/depends -type f | sort
  } | sort | xargs cat | md5sum | cut -f1 -d' '
}

function cksum_sys() {
  local CHROOT_DIR=$1
  {
    # sort each thing individually so the overall order is preserved
    find $SORCERY_LOCAL_CONFIG_DIR \
       -type f -not -name grimoire -not -path '*/depends/*'  -print | sort
    find $CHROOT_DIR/$STATE_ROOT/$SORCERY_LOCAL_CONFIG_DIR/depends -type f \
                                                                    | sort
    find $CHROOT_DIR/$STATE_ROOT/$SORCERY_STATE_DIR/depends -type f | sort
  } | sort | xargs cat | md5sum | cut -f1 -d' '
}

#---------------------------------------------------------------------
## Whatever needs to be done to make a chroot happens here.
#---------------------------------------------------------------------
function generate_chroot() {
  if [[ $FAKE ]] ; then
    message "Faking casting basesystem now"
    echo cast -c basesystem
  else
    message "Casting basesystem now, answer the questions"
    cast -c basesystem
  fi
}

function run_cmd() {
  eval "$@"
}

function fresh_chroot() {
  if ! [[ $RESUME_FRESH ]] ; then
    message "Original configs in $BACKUP_DIR, restore from there if bad things happen"
 
    # backup existing config
    backup_sorcery / "" $BACKUP_DIR &&

    # setup minimal config
    clean_slate / "$CHROOT_DIR" "$CHROOT_DIR" &&

    # run sorcery so user can setup stuff
    local msg="Configure stuff through sorcery menu?"
    local def=y
    while query "$msg" $def; do
      sorcery
      def=n
    done &&

    # TODO: check if branch changed, if so, do an update
    # TODO: ask if the grimoires are right
    # TODO: if not, add/switch things

    mkdir -p $CHROOT_DIR
  fi
  generate_chroot || {
    message "Chroot generation failed"
    if ! query "Keep going?" y; then
      message "run the following to put your system back the way it was:"
      message "chrootgen --config_dir $BACKUP_DIR restore"
      return 1
    fi
  }

  # backup config
  backup_sorcery / "$CHROOT_DIR" "$CONFIG_DIR" &&

  # restore configset into chroot
  restore_sorcery "$CHROOT_DIR" "" "" "$CONFIG_DIR"

  # restore original config
  # NOTE: the _ROOT vars are from the original . /etc/sorcery/config
  restore_sorcery / "$STATE_ROOT" "$INSTALL_ROOT" "$BACKUP_DIR"

  populate_chroot "$CHROOT_DIR"
}

function populate_chroot() {
  local CHROOT_DIR=$1
  # copy in skeleton
  cp -fa /usr/share/chrootgen/skeleton/* $CHROOT_DIR

  chroot $CHROOT_DIR /sbin/ldconfig
  # TODO: add sorcery to chroot
  inst_sorcery=""
  if test -f $SOURCE_CACHE/sorcery-$SORCERY_BRANCH.tar.bz2 ; then
    query "Install sorcery $SORCERY_BRANCH to chroot?" y &&
    inst_sorcery=$SOURCE_CACHE/sorcery-$SORCERY_BRANCH.tar.bz2
  elif query "Download sorcery $SORCERY_BRANCH to and install?" y; then
    wget http://download.sourcemge.org/sorcery/sorcery-$SORCERY_BRANCH.tar.bz2
    inst_sorcery=sorcery-$SORCERY_BRANCH.tar.bz2
  fi
  if [[ $inst_sorcery ]] ; then
    cd $CHROOT_DIR/tmp &&
    tar -xvjf $inst_sorcery &&
    cd sorcery &&
    ./install $CHROOT_DIR &&
    cd .. &&
    rm -rf sorcery &&
    sorcery_installed=yes
  fi || {
    message "Failed to install sorcery :-("
  }
  if test -x $CHROOT_DIR/usr/sbin/scribe ; then
    if query "Scribe add a grimoire?" y; then
      read -p "Which one? " -t 30 grim
      grim=${grim:-stable}
      chroot $CHROOT_DIR /usr/sbin/scribe add $grim
    fi
  fi

  if query "Tar up chroot into $CHROOT_DIR.tar.bz2?" n; then
    cd $CHROOT_DIR/..
    tar -cvjf $CHROOT_DIR.tar.bz2 $(basename $CHROOT_DIR)
  fi
  

  # ask if user wants to setup bind mounts
  if query "Setup bind mounts in $CHROOT_DIR?" y; then
    bind $CHROOT_DIR
  fi
 
}

function bind() {
  unbind $1 &>/dev/null
  local each
  for each in /dev /dev/pts /proc /sys /var/spool/sorcery; do
    mkdir -p ${1}${each}
    mount -o bind ${each} ${1}${each}
  done
}

function unbind() {
  for each in /dev/pts /dev /proc /sys /var/spool/sorcery; do
    umount ${1}${each}
  done
}

#---------------------------------------------------------------------
## Backup existing config, restore a different one, cast basesystem,
## backup updated configuration, restore original config.
#---------------------------------------------------------------------
function recreate_chroot() {
  local CHROOT_DIR=$1
  local STATE_ROOT=$2
  local INSTALL_ROOT=$3
  local BACKUP_DIR=$4
  local CONFIG_DIR=$5

  backup_sorcery "/" "" "$BACKUP_DIR" &&
  restore_sorcery "/" "$CHROOT_DIR" "$CHROOT_DIR" "$CONFIG_DIR" ||
  {
    message "failed to load config sets!"
    return 1
  }

  # run sorcery so user can setup stuff
  local msg="Configure stuff through sorcery menu?"
  local def=y
  while query "$msg" $def; do
    sorcery
    def=n
  done &&

  mkdir -p $CHROOT_DIR

  start_cksum=$(cksum_sys "$CHROOT_DIR")
  generate_chroot
  end_cksum=$(cksum_sys "$CHROOT_DIR")

  if [[ "$start_cksum" != "$end_cksum" ]] ; then
    if query "Config data changed, save it?" y ; then
      backup_sorcery / "$CHROOT_DIR" "$CONFIG_DIR"
    fi
  fi
  if query "Restore original config?" y; then
    # NOTE: the _ROOT vars are from the original . /etc/sorcery/config
    restore_sorcery / "$STATE_ROOT" "$INSTALL_ROOT" "$BACKUP_DIR"
  fi
}

#---------------------------------------------------------------------
## Run whatever task is requested.
#---------------------------------------------------------------------
function main() {
  default_config
  parse_args "$@"
  sanity_check || return $?

  TMP_DIR=/tmp/chrootgen.$$
  if test -d $TMP_DIR; then
    message "Removing old tmp dir in $TMP_DIR"
    rm -rf $TMP_DIR &&
    mkdir -p $TMP_DIR || {
      echo "unable to make tmp dir: $TMP_DIR"
      exit 1
    }
  fi

  case $TASK in 
     backup) backup_sorcery  "$CHROOT_DIR" "$STATE_ROOT" "$BACKUP_DIR" ;;
    restore) restore_sorcery "$CHROOT_DIR" "$STATE_ROOT" \
                             "$INSTALL_ROOT" "$CONFIG_DIR" ;;
   generate) generate_chroot ;;
  cksum_cfg) cksum_cfg "$CHROOT_DIR" "$STATE_ROOT" ;;
      fresh) fresh_chroot "$CHROOT_DIR" ;;
       bind) bind "$CHROOT_DIR" ;;
     unbind) unbind "$CHROOT_DIR" ;;
   populate) populate_chroot "$CHROOT_DIR" ;;
   recreate) recreate_chroot "$CHROOT_DIR" "$STATE_ROOT" "$INSTALL_ROOT" \
                     "$BACKUP_DIR" "$CONFIG_DIR" ;;

          *) usage; exit 1;;
  esac &&
  rm -rf $TMP_DIR
}

main "$@"
