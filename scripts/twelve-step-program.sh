#!/bin/sh
#
# twelve step iso generation script
# TODO: re-factor variable names and messaging logging
#

ROOT="/root"

  # step 1 get basesystem
  echo step 1
  cd "$ROOT"
  #wget http://10.0.0.199/smgl-stable-0.27-basesystem-x86.tar.bz2 &&
  echo unpacking build environment
  tar xf smgl-stable-0.27-basesystem-x86.tar.bz2 &&
  mv smgl-stable-0.27-basesystem-x86 "$ROOT"/build &&
  ls -l "$ROOT"
  test -d "$ROOT"/build || 
  echo 'step 1 failed' >> /var/log/sorcery/activity

  # step 1.5 (add resolv.conf and host sorcery url/compiler configuration)
  echo "step 1.5"
  cp /etc/resolv.conf "$ROOT"/build/etc/resolv.conf
  cp /etc/sorcery/local/compile_config "$ROOT"/build/etc/sorcery/local/compile_config
  echo LEAPFORWARD_URL=http://10.0.0.11/smgl/spool/ > "$ROOT"/build/etc/sorcery/local/url

  echo step 2 build kernel
  # may be handled by step 3 later on
  pushd /usr/src &&
  wget http://10.0.0.11/smgl/spool/linux-2.6.24.tar.bz2 &&
  tar xf linux-2.6.24.tar.bz2 &&
  ln -s linux-2.6.24 linux &&
  cp "$ROOT"/cauldron/data/config-2.6 /usr/src/linux/.config &&
  pushd linux &&
    yes ""|make oldconfig; make -j 4 &&
    make -j 4 && make modules -j 4 && make modules_install &&
  popd &&
  ls /lib/modules &&
  cp -fav /lib/modules/2.6.24-SMGL-iso "$ROOT"/build/lib/modules &&
  cp -fav /usr/src/linux-2.6.24 "$ROOT"/build/usr/src ||
  echo 'step 2 failed' >> /var/log/sorcery/activity

  echo step 3 build spells
  bash "$ROOT"/cauldron/scripts/spellcaster.sh "$ROOT"/build x86 ||
  echo 'step 3 failed' >> /var/log/sorcery/activity

  echo step 3.5 copy kernel sources to iso and sys tree
  # may be handled by step 3 later on
  cp -fav /lib/modules/2.6.24-SMGL-iso /tmp/cauldron/iso/lib/modules &&
  cp -fav /usr/src/linux-2.6.24 /tmp/cauldron/iso/usr/src ||
  echo 'step 3.5 failed' >> /var/log/sorcery/activity

  echo step 4 sanity fixes
  # TODO check for ppp/resolv.conf borkage
  if test -f "$ROOT"/build/etc/udev/rules.d/70-persistent-net.rules; then
    echo "twelve step program failure (udev rules)" >>  /var/log/sorcery/activity &&
    rm "$ROOT"/build/etc/udev/rules.d/70-persistent-net.rules
  fi ||
  echo 'step 4 failed' >> /var/log/sorcery/activity

  echo step 5 adjust system tree
  yes ""|bash "$ROOT"/cauldron/scripts/add-sauce.sh -s /tmp/cauldron/sys &&
  # TODO: cleanse --sweep &&
  rm /tmp/cauldron/sys/var/spool/sorcery/* &&
  rm /tmp/cauldron/sys/var/cache/sorcery/* &&
  rm /tmp/cauldron/sys/usr/src/* &&
  # TODO symlink with /var/spool/sorcery &&
  cp /usr/src/linux-2.6.24.tar.bz2 /tmp/cauldron/sys/usr/src ||
  echo 'step 5 failed' >> /var/log/sorcery/activity

  echo step 6 prune iso tree
  bash "$ROOT"/cauldron/scripts/cleaniso.sh -a /tmp/cauldron/iso ||
  echo 'step 6 failed' >> /var/log/sorcery/activity

  echo step 7 adjust iso tree
  yes ""|bash "$ROOT"/cauldron/scripts/add-sauce.sh -i /tmp/cauldron/iso ||
  echo 'step 7 failed' >> /var/log/sorcery/activity

  echo step 8 create system.tar.bz2
  bash "$ROOT"/cauldron/scripts/mksystem.sh /tmp/cauldron/sys /tmp/cauldron/iso/system.tar.bz2 ||
  echo 'step 8 failed' >> /var/log/sorcery/activity

  echo step 9 make initrd
  bash "$ROOT"/cauldron/scripts/mkinitrd.sh /tmp/cauldron/iso 2.6.24-SMGL-iso &&
  cp initrd.gz "$ROOT"/cauldron/iso/boot/initrd.gz ||
  echo 'step 9 failed' >> /var/log/sorcery/activity

  echo step 10 make iso
  cast -c cdrtools &&
  bash "$ROOT"/cauldron/scripts/mkrelease.sh /tmp/cauldron/iso omfga-test0 ||
  echo 'step 10 failed' >> /var/log/sorcery/activity

  # step 11
  # test in VM, cant get there from here
  # step 12
  # final QA, cant get there from here
