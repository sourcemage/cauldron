rm -f /tmp/isopackage-list
sed -n 's/^\(begin_\)\?unpack \([^ #]*\).*$/\2/p' ../data/iso.packages >/tmp/isopackage-list
while read SPELL ;do
  grep "^$SPELL:[^:]*:on:" /var/state/sorcery/depends |
  cut -d: -f2 |
  while read DEPCY ;do
    if ! grep -q "^$DEPCY$" /tmp/isopackage-list ;then
      echo "unsatisfied dependency $SPELL -> $DEPCY"
    fi
  done
done </tmp/isopackage-list
