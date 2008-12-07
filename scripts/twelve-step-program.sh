#!/bin/sh
#
# twelve step iso generation script
# TODO: re-factor variable names and messaging logging
#

  # step 1 (get basesystem)
  echo step 1
  cd /root
  wget http://10.0.0.199/smgl-stable-0.24-basesystem-x86.tar.bz2 &&
  tar xf smgl-stable-0.24-basesystem-x86.tar.bz2 &&
  mv smgl-stable-0.24-basesystem-x86 /root/build &&
  ls -l /root
  test -d /root/build || 
  echo 'step 1 failed' >> /var/log/sorcery/activity

  # step 2 (build spells)
  echo step 2
  bash /root/cauldron/scripts/spellcaster.sh -c /root/build x86 ||
  echo 'step 2 failed' >> /var/log/sorcery/activity

  
  # step 3 (build kernel)
  echo step 3
  pushd /usr/src &&
  wget http://10.0.0.11/smgl/spool/linux-2.6.24.tar.bz2 &&
  tar xf linux-2.6.24.tar.bz2 &&
  ln -s linux-2.6.24 linux &&
  cp /root/cauldron/data/config-2.6 /usr/src/linux/.config &&
  pushd linux &&
    yes ""|make oldconfig; make -j 4 &&
    make -j 4 && make modules -j 4 && make modules_install &&
  popd &&
  ls /lib/modules &&
  cp -fav /lib/modules/2.6.24 /root/build/lib/modules &&
  cp -fav /usr/src/linux-2.6.22 /root/build/usr/src ||
  echo 'step 3 failed' >> /var/log/sorcery/activity


  # step 4
  echo step 4
  if test -f /etc/udev/rules.d/70-persistent-net.rules; then
    echo "twelve step program failure (udev rules)" >>  /var/log/sorcery/activity &&
    rm /etc/udev/rules.d/70-persistent-net.rules
  fi ||
  echo 'step 4 failed' >> /var/log/sorcery/activity

  # step 5 (create iso and system tree)
  echo step 5
  cp -fav build iso &&
  cp -fav build system &&
  bash /root/cauldron/scripts/spellcaster.sh -d system x86 ||
  echo 'step 5 failed' >> /var/log/sorcery/activity

  # step 6 (adjust system tree)
  echo step 6
  yes ""|bash /root/cauldron/scripts/add-sauce.sh -s /root/system &&
  rm -rf /root/system/var/spool/sorcery/* &&
  rm -rf /root/system/var/cache/sorcery/* &&
  rm -rf /root/system/usr/src/* &&
  # TODO symlink with /var/spool/sorcery &&
  cp /usr/src/linux-2.6.24.tar.bz2 /root/system/usr/src ||
  echo 'step 6 failed' >> /var/log/sorcery/activity
  
  # step 7 (adjust iso tree)
  echo step 7
  bash /root/cauldron/scripts/cleaniso.sh -a /root/iso &&
  yes ""|bash /root/cauldron/scripts/add-sauce.sh -i /root/iso ||
  echo 'step 7 failed' >> /var/log/sorcery/activity

  # step 8 (create system.tar.bz2)
  echo step 8
  mkdir -p /root/cauldron/iso/ &&
  bash /root/cauldron/scripts/mksystem.sh /root/system /root/cauldron/iso/system.tar.bz2 ||
  echo 'step 8 failed' >> /var/log/sorcery/activity

  # step 9
  echo step 9
  bash /root/cauldron/scripts/mkinitrd.sh /root/iso 2.6.24 &&
  cp initrd.gz /root/cauldron/iso/boot/initrd.gz ||
  echo 'step 9 failed' >> /var/log/sorcery/activity

  # step 10
  echo step 10
  bash /root/cauldron/scripts/mkrelease.sh /root/iso omfga-test0 ||
  echo 'step 10 failed' >> /var/log/sorcery/activity

  # step 11
  # test in VM, cant get there from here
  # step 12
  # final QA, cant get there from here
