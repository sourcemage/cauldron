#!/bin/sh
#
# twelve step iso generation script
# TODO: re-factor variable names and messaging logging
#

ROOT="/root"
ROOTBUILD=$ROOT/build
CAULDRON_SRC=$ROOT/cauldron
SYSBUILD=/tmp/cauldron/sys
ISOBUILD=/tmp/cauldron/iso
KERNEL_VERSION=2.6.27.10

  # step 1 get basesystem
  echo step 1
  cd "$ROOT"
  #wget http://10.0.0.199/smgl-stable-0.27-basesystem-x86.tar.bz2 &&
  echo unpacking build environment
  tar xf smgl-stable-0.27-basesystem-x86.tar.bz2 &&
  mv smgl-stable-0.27-basesystem-x86 "$ROOTBUILD" &&
  ls -l "$ROOT"
  test -d "$ROOTBUILD" || 
  echo 'step 1 failed' >> /var/log/sorcery/activity

  # step 1.5 (add host sorcery url/compiler configuration)
  echo "step 1.5"
  cp /etc/sorcery/local/compile_config "$ROOTBUILD"/etc/sorcery/local/compile_config
  echo LEAPFORWARD_URL=http://10.0.0.11/smgl/spool/ > "$ROOTBUILD"/etc/sorcery/local/url

  echo step 2 build kernel
  # may be handled by step 3 later on
  pushd /usr/src &&
  #wget http://10.0.0.11/smgl/spool/linux-$KERNEL_VERSION.tar.bz2 &&
  #tar xf linux-$KERNEL_VERSION.tar.bz2 &&
  wget --progress=dot http://kernel.org/pub/linux/kernel/v2.6/linux-$KERNEL_VERSION.tar.gz &&
  tar xf linux-$KERNEL_VERSION.tar.gz &&
  ln -s linux-$KERNEL_VERSION linux &&
  cp "$CAULDRON_SRC"/data/config-2.6 /usr/src/linux/.config &&
  pushd linux &&
    yes ""|make oldconfig; make -j 4 &&
    make -j 4 && make modules -j 4 && make modules_install &&
  popd &&
  ls /lib/modules &&
  cp -fav /lib/modules/$KERNEL_VERSION-SMGL-iso "$ROOTBUILD"/lib/modules &&
  cp -fav /usr/src/linux-$KERNEL_VERSION "$ROOTBUILD"/usr/src &&
  ln -s linux-$KERNEL_VERSION "$ROOTBUILD"/usr/src/linux ||
  echo 'step 2 failed' >> /var/log/sorcery/activity

  echo step 3 build spells
  bash "$CAULDRON_SRC"/scripts/spellcaster.sh "$ROOTBUILD" x86 || {
    echo 'step 3 failed' >> /var/log/sorcery/activity
    exit
  }

  echo step 3.5 copy kernel sources to iso and sys tree
  # may be handled by step 3 later on
  cp -fav /usr/src/linux-$KERNEL_VERSION "$ISOBUILD"/usr/src ||
  echo 'step 3.5 failed' >> /var/log/sorcery/activity

  echo step 4 adjust system tree
  bash "$CAULDRON_SRC"/scripts/add-sauce.sh -o -s "$SYSBUILD" &&
  cp /usr/src/linux-$KERNEL_VERSION.tar.bz2 "$SYSBUILD"/var/spool/sorcery &&
  ln -sf /var/spool/sorcery/linux-$KERNEL_VERSION.tar.bz2 "$SYSBUILD"/usr/src/linux-$KERNEL_VERSION.tar.bz2 ||
  echo 'step 4 failed' >> /var/log/sorcery/activity

  echo step 5 prune iso tree
  bash "$CAULDRON_SRC"/scripts/cleaniso.sh "$ISOBUILD" ||
  echo 'step 5 failed' >> /var/log/sorcery/activity

  echo step 6 adjust iso tree
  bash "$CAULDRON_SRC"/scripts/add-sauce.sh -o -i "$ISOBUILD" ||
  echo 'step 6 failed' >> /var/log/sorcery/activity

  echo step 7 create system.tar.bz2
  bash "$CAULDRON_SRC"/scripts/mksystem.sh -s "$SYSBUILD" -i "$ISOBUILD" ||
  echo 'step 7 failed' >> /var/log/sorcery/activity

  echo step 8 make initrd
  bash "$CAULDRON_SRC"/scripts/mkinitrd.sh -i "$ISOBUILD" $KERNEL_VERSION-SMGL-iso ||
  echo 'step 8 failed' >> /var/log/sorcery/activity

  echo step 9 make iso
  cast -c cdrtools &&
  bash "$CAULDRON_SRC"/scripts/mkrelease.sh -i "$ISOBUILD" omfga-test0 ||
  echo 'step 9 failed' >> /var/log/sorcery/activity

  # step 10
  # test in VM and final QA, cant get there from here
