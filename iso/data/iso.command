#!/bin/bash

touch ${ISO_DIR}/etc/modules.devfsd # can't generate those on the fly,
touch ${ISO_DIR}/etc/modules.conf   # just make sure they exist
touch ${ISO_DIR}/etc/modules
touch ${ISO_DIR}/etc/modprobe.devfsd # HACK
touch ${ISO_DIR}/etc/modprobe.conf
touch ${ISO_DIR}/lib/modules/${KERNEL_VERSION}/modules.dep

# just-in-time replacing of templates

function isocmd_gversion() {
  local GDIR
  GDIR=$(sed -n 's/^[^#]*GRIMOIRE_DIR\[0\]=//p' /etc/sorcery/local/grimoire)
  echo -n "${GDIR##*/} grimoire"
  if [[ -e $GDIR/GRIMOIRE_VERSION ]] ;then
    echo -n ", version "
    head -n 1 $GDIR/GRIMOIRE_VERSION
  else
    echo ""
  fi
}

if [[ -d $ISO_DIR/isolinux ]] ;then
  sed -i "s/@INITRD_SIZE@/$(cat $DATA_DIR/initrd.size)/g" \
    $ISO_DIR/isolinux/isolinux.cfg
  sed -i "s/@GRIMOIRE_VERSION@/$(isocmd_gversion)/g" \
    $ISO_DIR/isolinux/isolinux.msg
elif [[ -d $ISO_DIR/yaboot ]] ;then
  sed -i "s/@INITRD_SIZE@/$(cat $DATA_DIR/initrd.size)/g" \
    $ISO_DIR/yaboot/yaboot.conf
  sed -i "s/@GRIMOIRE_VERSION@/$(isocmd_gversion)/g" \
    $ISO_DIR/yaboot/yaboot.msg
else
  echo "WARNING: Unable to store initrd size and grimoire version:" >&2
  echo "         Unknown bootloader." >&2
  false
fi
