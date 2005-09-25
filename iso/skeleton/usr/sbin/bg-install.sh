#!/bin/bash
DATA_DIR=/usr/share/smgl.install
MODULE_DIR=$DATA_DIR/modules
TEMPLATE_DIR=$DATA_DIR/templates
STATE_DIR=/var/lib/smgl.install

TMP_DIR=/tmp
DEPENDS_DIR=$TMP_DIR/installer_depends
FINALFILES=$TMP_DIR/finalfiles
INSTALLER_DEBUG=$TMP_DIR/installer_debug

export PATH="/bin:/usr/bin:/sbin:/usr/sbin"
export  HOME="/root"

[ -z $ARCH ] && ARCH=`uname -m`
[ -z $TARGET ] && TARGET=/mnt/root

for inst_MODULE in $MODULE_DIR/* ;do
  . $inst_MODULE #This has to be a global :/
done

function cleanup() {
  unlock_resource SI_HP_QUEUE
  unlock_resource SI_SPELL_QUEUE
  exit 1
}

function main() {
  # Sleep until we get stuff to do
  echo "Waiting for installation to begin..."
  wait_depends install_start

  local spell
  local idle=false
  # Work through queues
  while true ;do
    if test -e $SI_QUEUE_DIR/debug ;then # waits debugging mode
      echo "Waiting for installer to need a spell"
      while ! test -e $SI_QUEUE_DIR/force_run ;do
        sleep 1
      done
    fi
    si_pop &&
    idle=false ||
    {
      if ! $idle ;then
        echo "nothing to do"
        idle=true
      fi
      sleep 2
    }
    rm -f $SI_QUEUE_DIR/force_run
  done
}

if [ -f $STATE_DIR/version ]; then
  . $STATE_DIR/version 
else
  INSTALLER_VERSION=`date +%Y%m%d`-debug
  SORCERY_VERSION=stable #wild guess
  GRIMOIRE_VERSION=stable
fi

trap  "true"  INT QUIT
trap cleanup TERM

# Give the main installer a while to start up the environment
sleep 10
# Give resources to main installer whenever it needs them
renice 19 $$
# Start the main loop
main
