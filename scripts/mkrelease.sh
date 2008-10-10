#!/bin/bash

TARGET=$1
VERSION=$2

[[ $# -lt 2 ]] && usage

GRIMOIRE_VER=$(< "$TARGET"/var/lib/sorcery/codex/stable/VERSION)

function usage() {
cat << EOF
Usage: $(basename $0) /path/to/iso/chroot VERSION
EOF
exit
}

for file in $(grep -qr '@ISO_VERSION@' $TARGET/{etc,isolinux,usr/share/doc/smgl.install}/*)
do
	sed -i "s/@ISO_VERSION@/$VERSION/" "$file"
done

sed -i "s/@GRIMOIRE_VERSION@/$GRIMOIRE_VER/" "$TARGET"/isolinux/isolinux.msg

$(dirname $0)/mkiso.sh -k "$TARGET" "smgl-$VERSION"

