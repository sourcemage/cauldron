#set this to e.g. /opt/old-root if you have an old chroot (recommended)
SOURCE_ROOT=/

DESTINATION_ROOT=/opt/chroot

all: iso

sanitize_source:
	if [ "${SOURCE_ROOT}" != "/" ] ;then \
	  ./sanitize_chroot ${SOURCE_ROOT} \
	fi

${DESTINATION_ROOT}: sanitize_source
	./mkroot ${SOURCE_ROOT} ${DESTINATION_ROOT}

sanitize_dest: ${DESTINATION_ROOT}
	./sanitize_chroot ${DESTINATION_ROOT}

target_copy_files: sanitize_dest
	./mkprep ${DESTINATION_ROOT}/root/p4
	touch target_copy_files

target_create_tarballs: target_copy_files sanitize_dest
	chroot ${DESTINATION_ROOT} bash -c "cd /root/p4/generation-scripts ; ./first_build"
	touch target_create_tarballs

iso: target_create_tarballs sanitize_dest
	chroot ${DESTINATION_ROOT} bash -c "cd /root/p4/generation-scripts ; ./mk-smgl-iso"
	@echo "phew, we're done. look for the ISO in ${DESTINATION_ROOT}"

.PHONY: sanitize_source sanitize_dest iso
