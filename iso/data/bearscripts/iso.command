touch ${ISO_DIR}/etc/modules.devfsd # can't generate those on the fly,
touch ${ISO_DIR}/etc/modules.conf   # just make sure they exist
touch ${ISO_DIR}/etc/modprobe.devfsd # HACK
touch ${ISO_DIR}/etc/modprobe.conf
touch ${ISO_DIR}/lib/modules/${KERNEL_VERSION}/modules.dep
