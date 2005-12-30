#!/bin/bash

TARGET=${1:-/}

DESC_FILE=/usr/share/smgl.install/group-descriptions

Username="changeme"
FullName="John Example"
Home="/home/changeme"
Shell="/bin/bash"
Group="users"
DEF="Username"

function set_var() {
  WHAT="$2"
  shift 2
  case $WHAT in
    Username)
              [[ $Home == "/home/$Username" ]] && Home="/home/$*"
           ;;
  esac
  eval "$WHAT=\$*"
  DEF=$WHAT
}

function get_settings() {
  while true ;do
    HELP="Please set basic options for the user.
          Note that the username may not contain special characters
          or spaces."
    INPUT=$(dialog --backtitle "SMGL fancy user add tool"  \
                   --stdout --extra-label "Change"         \
                   --default-item "$DEF" --trim            \
                   --inputmenu "$HELP" 20 60 10            \
                   "Username"  "$Username"                 \
                   "FullName"  "$FullName"                 \
                   "Home"      "$Home"                     \
                   "Shell"     "$Shell"                    \
                   "Group"     "$Group"                    )
    RC=$?
    case $RC in
      255) return 1 ;;
        1) return 1 ;;
        0) return 0 ;;
        3) set_var $INPUT ;;
        *) echo "Weird things are happening!" ; return 1 ;;
    esac
  done
}

function get_groups() {
  Moregroups=${Moregroups:-$Group}
  i=0
  while read j ;do
    GNAME=${j%%:*}
    GNUM=${j%:*}
    GNUM=${GNUM##*:}
    GROUPSES[i++]="$GNAME"
    GROUPSES[i++]="$GNUM"
    [[ $Moregroups =~ '(^|,)'$GNAME'(,|$)' ]] &&
      GROUPSES[i++]="on"      ||
      GROUPSES[i++]="off"
    if grep -q "^$GNAME:" $DESC_FILE ;then
      GROUPSES[i++]="$(sed -n "s/^$GNAME://p" $DESC_FILE)"
    else
      GROUPSES[i++]="No description available."
    fi
  done <$TARGET/etc/group

  HELP="Select any groups that the new user should be part of.
        Usually, less is better here."
  # We use extra-button so that the changed groups are saved anyway
  groups=$(dialog --backtitle "SMGL fancy user add tool" \
                  --stdout --single-quoted   \
                  --no-cancel --extra-button \
                  --extra-label "Back"       \
                  --item-help                \
                  --checklist "$HELP" 0 0 0  \
                  "${GROUPSES[@]}"           )
  rc=$?
  Moregroups=$(echo $groups | tr ' ' ',')
  return $rc
}

get_settings &&
while ! get_groups ;do # Allow a "back" button
  get_settings || exit 1
done

[[ -e "$TARGET$Home" ]] || HOMEMADE="-m"

chroot $TARGET groupadd -f "$Group" #Create group if it doesn't exist yet

chroot $TARGET useradd -c "$FullName" -d "$Home" -g "$Group" -G $Moregroups $HOMEMADE -s "$Shell" "$Username"
chroot $TARGET passwd "$Username"
