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
  wget http://10.0.0.11/smgl/spool/linux-2.6.24.tar.bz2 &&
  tar xf linux-2.6.24.tar.bz2 &&
  ln -s linux-2.6.24 linux &&
  cp "$CAULDRON_SRC"/data/config-2.6 /usr/src/linux/.config &&
  pushd linux &&
    yes ""|make oldconfig; make -j 4 &&
    make -j 4 && make modules -j 4 && make modules_install &&
  popd &&
  ls /lib/modules &&
  cp -fav /lib/modules/2.6.24-SMGL-iso "$ROOTBUILD"/lib/modules &&
  cp -fav /usr/src/linux-2.6.24 "$ROOTBUILD"/usr/src ||
  echo 'step 2 failed' >> /var/log/sorcery/activity

  echo step 3 build spells
  bash "$CAULDRON_SRC"/scripts/spellcaster.sh "$ROOTBUILD" x86 ||
  echo 'step 3 failed' >> /var/log/sorcery/activity

  echo step 3.5 copy kernel sources to iso and sys tree
  # may be handled by step 3 later on
  cp -fav /lib/modules/2.6.24-SMGL-iso "$ISOBUILD"/lib/modules &&
  cp -fav /usr/src/linux-2.6.24 "$ISOBUILD"/usr/src ||
  echo 'step 3.5 failed' >> /var/log/sorcery/activity

  echo step 4 sanity fixes
  # TODO check for ppp/resolv.conf borkage
  if test -f "$ROOTBUILD"/etc/udev/rules.d/70-persistent-net.rules; then
    echo "twelve step program failure (udev rules)" >>  /var/log/sorcery/activity &&
    rm "$ROOTBUILD"/etc/udev/rules.d/70-persistent-net.rules
  fi ||
  echo 'step 4 failed' >> /var/log/sorcery/activity

  echo step 5 adjust system tree
  yes ""|bash "$CAULDRON_SRC"/scripts/add-sauce.sh -s "$SYSBUILD" &&
  # TODO: cleanse --sweep &&
  rm "$SYSBUILD"/var/spool/sorcery/* &&
  rm "$SYSBUILD"/var/cache/sorcery/* &&
  rm "$SYSBUILD"/usr/src/* &&
  # TODO symlink with /var/spool/sorcery &&
  cp /usr/src/linux-2.6.24.tar.bz2 "$SYSBUILD"/usr/src ||
  echo 'step 5 failed' >> /var/log/sorcery/activity

  echo step 6 prune iso tree
  bash "$CAULDRON_SRC"/scripts/cleaniso.sh -a "$ISOBUILD" ||
  echo 'step 6 failed' >> /var/log/sorcery/activity

  echo step 7 adjust iso tree
  yes ""|bash "$CAULDRON_SRC"/scripts/add-sauce.sh -i "$ISOBUILD" ||
  echo 'step 7 failed' >> /var/log/sorcery/activity

  echo step 8 create system.tar.bz2
  bash "$CAULDRON_SRC"/scripts/mksystem.sh "$SYSBUILD" "$ISOBUILD"/system.tar.bz2 ||
  echo 'step 8 failed' >> /var/log/sorcery/activity

  echo step 9 make initrd
  bash "$CAULDRON_SRC"/scripts/mkinitrd.sh "$ISOBUILD" 2.6.24-SMGL-iso &&
  cp initrd.gz "$CAULDRON_SRC"/iso/boot/initrd.gz ||
  echo 'step 9 failed' >> /var/log/sorcery/activity

  echo step 10 make iso
  cast -c cdrtools &&
  bash "$CAULDRON_SRC"/scripts/mkrelease.sh "$ISOBUILD" omfga-test0 ||
  echo 'step 10 failed' >> /var/log/sorcery/activity

  # step 11
  # test in VM, cant get there from here
  # step 12
  # final QA, cant get there from here
